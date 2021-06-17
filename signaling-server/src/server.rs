extern crate actix;

extern crate log;

extern crate rand;

use actix::prelude::*;

use log::{error, warn, info, log_enabled, Level};

use rand::{rngs::ThreadRng, Rng};

use std::collections::{HashMap, HashSet};

const LOBBY_STRING_CHARS: &str = "abcdefghijklmnopqrstuvwxyz0123456789";
const LOBBY_STRING_LEN: u32 = 5;

const MAX_LOBBIES: usize = 5000;
const MAX_LOBBY_PLAYERS: usize = 10;

#[derive(Message)]
#[rtype(i32)]
pub struct Connect {
    pub addr: Addr<super::WsSession>,
}

#[derive(Message)]
pub struct Disconnect {
    pub from_id: i32,
    pub lobby: Option<String>,
}

#[derive(Message)]
pub struct Host {
    pub from_id: i32,
}

#[derive(Message)]
pub struct Join {
    pub from_id: i32,
    pub lobby: String,
}

#[derive(Message)]
pub struct Enter {
    pub lobby: String,
}

#[derive(Message)]
pub struct Decline {
    pub reason: String,
}

#[derive(Message)]
pub struct NewPeer {
    pub peer_id: i32,
    pub connecting: bool,
}

#[derive(Message)]
pub struct Lock {
    pub from_id: i32,
    pub lobby: String,
    pub lock: bool,
}

#[derive(Message)]
pub struct Offer {
    pub from_id: i32,
    pub dest_id: i32,
    pub payload: String,
}

#[derive(Message)]
pub struct Answer {
    pub from_id: i32,
    pub dest_id: i32,
    pub payload: String,
}

#[derive(Message)]
pub struct Candidate {
    pub from_id: i32,
    pub dest_id: i32,
    pub payload: String,
}

struct Lobby {
    players: HashSet<i32>,
    host: i32,
    locked: bool,
}

pub struct SignalingServer {
    sessions: HashMap<i32, Addr<super::WsSession>>,
    lobbies: HashMap<String, Lobby>,
    rng: ThreadRng,
}

impl Default for SignalingServer {
    fn default() -> SignalingServer {
        SignalingServer {
            sessions: HashMap::new(),
            lobbies: HashMap::new(),
            rng: rand::thread_rng(),
        }
    }
}

impl Actor for SignalingServer {
    type Context = Context<Self>;
}

impl Handler<Connect> for SignalingServer {
    type Result = i32;

    fn handle(&mut self, msg: Connect, _: &mut Self::Context) -> Self::Result {
        let id;
        loop {
            let possible_id = self.rng.gen::<i32>().abs();
            if possible_id > 0 && !self.sessions.contains_key(&possible_id) {
                id = possible_id;
                self.sessions.insert(possible_id, msg.addr);
                break;
            }
        }

        info!("Player {0} connected", id);

        id
    }
}

impl Handler<Disconnect> for SignalingServer {
    type Result = ();

    fn handle(&mut self, msg: Disconnect, _: &mut Self::Context) {
        if let Some(lobby_string) = &msg.lobby {
            let lobby = self.lobbies.get_mut(lobby_string).unwrap();
            lobby.players.remove(&msg.from_id);

            if lobby.players.len() == 0 {
                self.lobbies.remove(lobby_string);
                info!("Removed lobby {0}", lobby_string);
            }
            // Use an else if to prevent double mut borrows (plus if the lobby is empty, you don't
            // need to assign a new host)
            else if lobby.host == msg.from_id {
                let mut lowest_id = None;
                for player in lobby.players.iter() {
                    match lowest_id {
                        Some(id) => {
                            if player < id {
                                lowest_id = Some(player);
                            }
                        },
                        None => lowest_id = Some(player),
                    }
                }
                lobby.host = *lowest_id.unwrap();

                info!("Player {0} now host of lobby {1}", lobby.host, lobby_string);
            }
        }

        self.sessions.remove(&msg.from_id);

        if log_enabled!(Level::Info) {
            if msg.lobby == None {
                info!("Player {0} disconnected", msg.from_id);
            }
            else {
                info!("Player {0} disconnected from lobby {1}", msg.from_id, msg.lobby.unwrap());
            }
        }
    }
}

impl Handler<Host> for SignalingServer {
    type Result = ();

    fn handle(&mut self, msg: Host, _: &mut Self::Context) {
        if self.lobbies.len() >= MAX_LOBBIES {
            let from_addr = self.sessions.get(&msg.from_id).unwrap();
            let decline_msg = Decline { reason: "Server has reached the maximum number of lobbies".to_owned() };
            from_addr.do_send(decline_msg);
            return;
        }

        let lobby_string: String;
        loop {
            let mut lobby_chars = Vec::new();
            for _ in 0..LOBBY_STRING_LEN {
                let lobby_char_id = self.rng.gen_range(0, LOBBY_STRING_CHARS.len());
                lobby_chars.push(LOBBY_STRING_CHARS.chars().nth(lobby_char_id).unwrap());
            }
            let possible_lobby_string = lobby_chars.into_iter().collect();
            if !self.lobbies.contains_key(&possible_lobby_string) {
                lobby_string = possible_lobby_string;
                break;
            }
        }

        let mut lobby_ids = HashSet::new();
        lobby_ids.insert(msg.from_id);
        let lobby = Lobby { players: lobby_ids, host: msg.from_id, locked: false };
        self.lobbies.insert(lobby_string.clone(), lobby);

        info!("Player {0} hosted lobby {1}", msg.from_id, lobby_string);

        let enter_msg = Enter { lobby: lobby_string, };
        let from_addr = self.sessions.get(&msg.from_id).unwrap();
        from_addr.do_send(enter_msg);
    }
}

impl Handler<Join> for SignalingServer {
    type Result = ();

    fn handle(&mut self, msg: Join, _: &mut Self::Context) {
        let from_addr = self.sessions.get(&msg.from_id).unwrap();

        let lobby;
        match self.lobbies.get_mut(&msg.lobby) {
            Some(inner_lobby) => lobby = inner_lobby,
            None => {
                let decline_msg = Decline { reason: "Lobby does not exist".to_owned() };
                from_addr.do_send(decline_msg);
                info!("Player {0} tried to join lobby {1}, but lobby {1} does not exist", msg.from_id, msg.lobby);
                return;
            }
        }

        if lobby.locked == true {
            let decline_msg = Decline { reason: "Lobby is locked".to_owned() };
            from_addr.do_send(decline_msg);
            info!("Player {0} tried to join lobby {1}, but lobby {1} is locked", msg.from_id, msg.lobby);
            return;
        }

        if lobby.players.len() >= MAX_LOBBY_PLAYERS {
            let decline_msg = Decline { reason: "Lobby is already full".to_owned() };
            from_addr.do_send(decline_msg);
            info!("Player {0} tried to join lobby {1}, but lobby {1} is full", msg.from_id, msg.lobby);
            return;
        }

        info!("Player {0} joined lobby {1}", msg.from_id, msg.lobby);

        let enter_msg = Enter { lobby: msg.lobby };
        from_addr.do_send(enter_msg);

        for id in lobby.players.iter() {
            let addr = self.sessions.get(id).unwrap();
            let new_peer_msg = NewPeer { peer_id: msg.from_id, connecting: true, };
            addr.do_send(new_peer_msg);

            let new_peer_msg = NewPeer { peer_id: *id, connecting: false };
            from_addr.do_send(new_peer_msg);
        }

        lobby.players.insert(msg.from_id);
    }
}

impl Handler<Lock> for SignalingServer {
    type Result = ();

    fn handle(&mut self, msg: Lock, _: &mut Self::Context) {
        if let Some(lobby) = self.lobbies.get_mut(&msg.lobby) {
            if msg.from_id != lobby.host {
                warn!("Received lock message from player {0}, but player {0} is not the lobby host", msg.from_id);
                return;
            }

            lobby.locked = msg.lock;
            if log_enabled!(Level::Info) {
                if lobby.locked {
                    info!("Lobby {0} locked", msg.lobby);
                }
                else {
                    info!("Lobby {0} unlocked", msg.lobby);
                }
            }
        }
        else {
            error!("Received lock message for lobby {0}, but lobby {0} does not exist", msg.lobby);
        }
    }
}

impl Handler<Offer> for SignalingServer {
    type Result = ();

    fn handle(&mut self, msg: Offer, _: &mut Self::Context) {
        let dest_addr = self.sessions.get(&msg.dest_id).unwrap();
        dest_addr.do_send(msg);
    }
}

impl Handler<Answer> for SignalingServer {
    type Result = ();

    fn handle(&mut self, msg: Answer, _: &mut Self::Context) {
        let dest_addr = self.sessions.get(&msg.dest_id).unwrap();
        dest_addr.do_send(msg);
    }
}

impl Handler<Candidate> for SignalingServer {
    type Result = ();

    fn handle(&mut self, msg: Candidate, _: &mut Self::Context) {
        let dest_addr = self.sessions.get(&msg.dest_id).unwrap();
        dest_addr.do_send(msg);
    }
}
