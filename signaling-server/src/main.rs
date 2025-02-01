extern crate actix;
extern crate actix_web;
extern crate actix_web_actors;

extern crate log;
extern crate env_logger;

use actix::prelude::*;
use actix_web::{web, App, Error, HttpRequest, HttpResponse, HttpServer};
use actix_web_actors::ws;

use log::{warn, info};

use std::time::{Duration, Instant};

mod server;

const HEARTBEAT_INTERVAL: Duration = Duration::from_secs(5);
const CLIENT_TIMEOUT: Duration = Duration::from_secs(10);

pub struct WsSession {
    id: i32,
    lobby: Option<String>,
    server: Addr<server::SignalingServer>,
    heartbeat: Instant,
}

impl Actor for WsSession {
    type Context = ws::WebsocketContext<Self>;

    fn started(&mut self, ctx: &mut Self::Context) {
        self.heartbeat(ctx);

        let addr = ctx.address();
        self.server
            .send(server::Connect {
                addr: addr,
            })
            .into_actor(self)
            .then(|result, actor, ctx| {
                match result {
                    Ok(result) => {
                        actor.id = result;
                        ctx.text(format!("I:{0}", actor.id));
                    },
                    _ => ctx.stop(),
                }
                fut::ok(())
            })
            .wait(ctx);
    }

    fn stopping(&mut self, _: &mut Self::Context) -> Running {
        self.server.do_send(server::Disconnect {
            from_id: self.id,
            lobby: self.lobby.clone(),
        });
        Running::Stop
    }
}

/* Since the upcoming handlers will be dealing with messages in a custom signaling protocol, I
 * might as well document the protocol.
 * Each message starts with a single letter denoting the type of message, followed by a : and then
 * the message payload if the message requires a payload.
 *
 * Here's each message the client can send:
 * H: No payload, requests the server to create a new random lobby
 * J: Requests to join a lobby, the lobby string is the payload
 * L: Update the lock status of the lobby, payload is either L or U (L for lock, U for unlock)
 * O: Sends a WebRTC offer, payload is the destination id, followed by a "\n", and then the offer
 * A: Sends a WebRTC answer, payload is the destination id, followed by a "\n", and then the offer
 * C: Sends a WebRTC candidate, payload is the destination id, followed by a "\n", and then the offer
 *
 * Here's each message the server can send:
 * E: Tells the client they can join the lobby, the lobby string is the payload
 * D: Tells the client they can't join, the reason is the payload
 * N: Tells the client to make a new connection. Payload starts with either a C or an E (E means
 * this is an existing player, while C means this is a connecting player), followed by a ",", and
 * then the player's id
 * O: Sends a WebRTC offer, payload is the sender id, followed by a "\n", and then the offer
 * A: Sends a WebRTC answer, payload is the sender id, followed by a "\n", and then the offer
 * C: Sends a WebRTC candidate, payload is the sender id, followed by a "\n", and then the offer
 */

impl Handler<server::Enter> for WsSession {
    type Result = ();

    fn handle(&mut self, msg: server::Enter, ctx: &mut Self::Context) {
        ctx.text(format!("E:{0}", msg.lobby));
        self.lobby = Some(msg.lobby);
    }
}

impl Handler<server::Decline> for WsSession {
    type Result = ();

    fn handle(&mut self, msg: server::Decline, ctx: &mut Self::Context) {
        ctx.text(format!("D:{0}", msg.reason));
    }
}

impl Handler<server::NewPeer> for WsSession {
    type Result = ();

    fn handle(&mut self, msg: server::NewPeer, ctx: &mut Self::Context) {
        if msg.connecting {
            ctx.text(format!("N:C,{0}", msg.peer_id));
        }
        else {
            ctx.text(format!("N:E,{0}", msg.peer_id));
        }
    }
}

impl Handler<server::Offer> for WsSession {
    type Result = ();

    fn handle(&mut self, msg: server::Offer, ctx: &mut Self::Context) {
        ctx.text(format!("O:{0}\n{1}", msg.from_id, msg.payload));
    }
}

impl Handler<server::Answer> for WsSession {
    type Result = ();

    fn handle(&mut self, msg: server::Answer, ctx: &mut Self::Context) {
        ctx.text(format!("A:{0}\n{1}", msg.from_id, msg.payload));
    }
}

impl Handler<server::Candidate> for WsSession {
    type Result = ();

    fn handle(&mut self, msg: server::Candidate, ctx: &mut Self::Context) {
        ctx.text(format!("C:{0}\n{1}", msg.from_id, msg.payload));
    }
}

impl StreamHandler<ws::Message, ws::ProtocolError> for WsSession {
    fn handle(&mut self, msg: ws::Message, ctx: &mut Self::Context) {
        match msg {
            ws::Message::Ping(msg) => {
                self.heartbeat = Instant::now();
                ctx.pong(&msg);
            },
            ws::Message::Pong(_) => {
                self.heartbeat = Instant::now();
            },
            ws::Message::Text(text) => {
                match text.chars().nth(0).unwrap() {
                    'H' => {
                        self.server.do_send(server::Host {
                            from_id: self.id,
                        });
                    },
                    'J' => {
                        self.server.do_send(server::Join {
                            from_id: self.id,
                            // Make all characters lowercase to remove case-sensitivity (since the font has no different uppercase letters)
                            lobby: text[2..].to_lowercase(),
                        });
                    },
                    'L' => {
                        match text.chars().nth(2) {
                            Some('L') => {
                                self.server.do_send(server::Lock {
                                    from_id: self.id,
                                    lobby: self.lobby.clone().unwrap(),
                                    lock: true,
                                });
                            },
                            Some('U') => {
                                self.server.do_send(server::Lock {
                                    from_id: self.id,
                                    lobby: self.lobby.clone().unwrap(),
                                    lock: false,
                                });
                            },
                            _ => {
                                warn!("Received lock message with invalid payload");
                            },
                        }
                    },
                    'O' => {
                        let (header, payload) = text.split_at(text.find('\n').unwrap());
                        let payload = payload[1..].to_owned();
                        self.server.do_send(server::Offer {
                            from_id: self.id,
                            dest_id: header[2..].parse::<i32>().unwrap(),
                            payload: payload,
                        });
                    },
                    'A' => {
                        let (header, payload) = text.split_at(text.find('\n').unwrap());
                        let payload = payload[1..].to_owned();
                        self.server.do_send(server::Answer {
                            from_id: self.id,
                            dest_id: header[2..].parse::<i32>().unwrap(),
                            payload: payload,
                        });
                    },
                    'C' => {
                        let (header, payload) = text.split_at(text.find('\n').unwrap());
                        let payload = payload[1..].to_owned();
                        self.server.do_send(server::Candidate {
                            from_id: self.id,
                            dest_id: header[2..].parse::<i32>().unwrap(),
                            payload: payload,
                        });
                    },
                    _ => (),
                }
            },
            ws::Message::Close(_) => {
                ctx.stop();
            },
            _ => (),
        }
    }
}

impl WsSession {
    fn heartbeat(&self, ctx: &mut ws::WebsocketContext<Self>) {
        ctx.run_interval(HEARTBEAT_INTERVAL, |actor, ctx| {
            if Instant::now().duration_since(actor.heartbeat) > CLIENT_TIMEOUT {
                ctx.stop();
                return;
            }

            ctx.ping("");
        });
    }
}

fn websocket_route(
    req: HttpRequest,
    stream: web::Payload,
    server: web::Data<Addr<server::SignalingServer>>,
) -> Result<HttpResponse, Error> {
    ws::start(
        WsSession {
            id: 0,
            lobby: None,
            server: server.get_ref().clone(),
            heartbeat: Instant::now(),
        },
        &req,
        stream,
    )
}

fn main() {
    // Initialize the logging system w/ default level of info
    env_logger::from_env(env_logger::Env::default().default_filter_or("info")).init();
    info!("Logging system initialized");

    let system = System::new("signaling-server");
    let server = server::SignalingServer::default().start();

    HttpServer::new(move || {
        App::new()
            .data(server.clone())
            .service(web::resource("/").to(websocket_route))
    })
    .bind("0.0.0.0:7777")
    .unwrap()
    .start();

    system.run().unwrap();
}
