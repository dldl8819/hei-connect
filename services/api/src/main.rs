use std::{collections::HashMap, env, sync::Arc};

use axum::{
    extract::{Path, State},
    http::StatusCode,
    routing::{get, patch, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use tokio::sync::RwLock;
use tower_http::{cors::CorsLayer, trace::TraceLayer};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
use uuid::Uuid;

#[derive(Clone, Default)]
struct AppState {
    channels: Arc<RwLock<HashMap<Uuid, Channel>>>,
    sessions: Arc<RwLock<HashMap<Uuid, LiveSession>>>,
    signal_states: Arc<RwLock<HashMap<Uuid, SignalState>>>,
    support_intents: Arc<RwLock<HashMap<Uuid, SupportIntent>>>,
    cue_events: Arc<RwLock<HashMap<Uuid, Vec<GuidanceCueEvent>>>>,
    chat_messages: Arc<RwLock<HashMap<Uuid, Vec<LiveChatMessage>>>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
enum SessionStatus {
    WaitingForSupporter,
    Connected,
    Live,
    Paused,
    Ended,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
enum SafetyState {
    Ready,
    CheckRequired,
    StopNow,
    ConnectionLost,
}

#[derive(Debug, Clone, Serialize)]
struct HealthResponse {
    status: &'static str,
    service: &'static str,
}

#[derive(Debug, Deserialize)]
struct CreateChannelRequest {
    title: String,
    #[serde(default)]
    support_enabled: bool,
}

#[derive(Debug, Clone, Serialize)]
struct Channel {
    channel_id: Uuid,
    channel_code: String,
    channel_link: String,
    title: String,
    support_enabled: bool,
}

#[derive(Debug, Deserialize)]
struct CreateLiveSessionRequest {
    channel_id: Option<Uuid>,
    host_alias: Option<String>,
    purpose: LiveSessionPurpose,
    source_mode: LiveSourceMode,
    runner_vision_mode: Option<RunnerVisionMode>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
enum LiveSessionPurpose {
    AudioRoom,
    RunningGuide,
    DailyHelp,
    Conversation,
    Broadcast,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
enum LiveSourceMode {
    AudioOnly,
    ScreenShare,
    SelfieCamera,
    WorldCamera,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
enum RunnerVisionMode {
    Sighted,
    LowVision,
    Blind,
}

#[derive(Debug, Clone, Serialize)]
struct LiveSession {
    session_id: Uuid,
    join_code: String,
    join_link: String,
    channel_id: Option<Uuid>,
    purpose: LiveSessionPurpose,
    source_mode: LiveSourceMode,
    runner_vision_mode: Option<RunnerVisionMode>,
    status: SessionStatus,
    safety_state: SafetyState,
    host_alias: Option<String>,
}

#[derive(Debug, Deserialize)]
struct UpdateSafetyRequest {
    safety_state: SafetyState,
    reason: Option<String>,
}

#[derive(Debug, Deserialize)]
struct UpdateSessionStatusRequest {
    status: SessionStatus,
    reason: Option<String>,
}

#[derive(Debug, Serialize)]
struct SafetyResponse {
    session_id: Uuid,
    safety_state: SafetyState,
    reason: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
enum GuidanceCue {
    StopNow,
    SlowDown,
    KeepStraight,
    LeftSmall,
    RightSmall,
    ObstacleAhead,
    PersonAhead,
    CurbAhead,
    NarrowPath,
    HoldPace,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
enum CueSenderRole {
    Supporter,
    System,
}

#[derive(Debug, Deserialize)]
struct CreateGuidanceCueRequest {
    cue: GuidanceCue,
    sender_role: CueSenderRole,
}

#[derive(Debug, Clone, Serialize)]
struct GuidanceCueEvent {
    cue_event_id: Uuid,
    session_id: Uuid,
    sequence: usize,
    cue: GuidanceCue,
    sender_role: CueSenderRole,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
enum ChatSenderRole {
    Host,
    Supporter,
    System,
}

#[derive(Debug, Deserialize)]
struct CreateLiveChatMessageRequest {
    sender_role: ChatSenderRole,
    body: String,
}

#[derive(Debug, Clone, Serialize)]
struct LiveChatMessage {
    message_id: Uuid,
    session_id: Uuid,
    sequence: usize,
    sender_role: ChatSenderRole,
    body: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
enum SupportTier {
    Small,
    Medium,
    Large,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
enum SupportStatus {
    Pending,
}

#[derive(Debug, Deserialize)]
struct CreateSupportIntentRequest {
    channel_id: Option<Uuid>,
    session_id: Option<Uuid>,
    tier: SupportTier,
    message: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
struct SupportIntent {
    support_id: Uuid,
    channel_id: Option<Uuid>,
    session_id: Option<Uuid>,
    tier: SupportTier,
    status: SupportStatus,
    message: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
enum SignalRole {
    Host,
    Supporter,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
enum SdpType {
    Offer,
    Answer,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct SessionDescription {
    sdp_type: SdpType,
    sdp: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct IceCandidate {
    candidate: String,
    sdp_mid: Option<String>,
    sdp_m_line_index: Option<u16>,
    username_fragment: Option<String>,
}

#[derive(Debug, Deserialize)]
struct UpsertSessionDescriptionRequest {
    sdp_type: SdpType,
    sdp: String,
}

#[derive(Debug, Deserialize)]
struct AddIceCandidateRequest {
    role: SignalRole,
    candidate: IceCandidate,
}

#[derive(Debug, Clone, Serialize)]
struct SignalState {
    session_id: Uuid,
    offer: Option<SessionDescription>,
    answer: Option<SessionDescription>,
    host_ice_candidates: Vec<IceCandidate>,
    supporter_ice_candidates: Vec<IceCandidate>,
}

impl SignalState {
    fn new(session_id: Uuid) -> Self {
        Self {
            session_id,
            offer: None,
            answer: None,
            host_ice_candidates: Vec::new(),
            supporter_ice_candidates: Vec::new(),
        }
    }
}

#[tokio::main]
async fn main() {
    tracing_subscriber::registry()
        .with(tracing_subscriber::EnvFilter::new(
            env::var("RUST_LOG").unwrap_or_else(|_| "connect_api=info,tower_http=info".into()),
        ))
        .with(tracing_subscriber::fmt::layer())
        .init();

    let state = AppState::default();
    let app = Router::new()
        .route("/healthz", get(healthz))
        .route("/v1/channels", post(create_channel))
        .route("/v1/channels/code/{channel_code}", get(get_channel_by_code))
        .route("/v1/channels/{channel_id}", get(get_channel))
        .route("/v1/live-sessions", post(create_live_session))
        .route(
            "/v1/live-sessions/join-code/{join_code}",
            get(get_live_session_by_join_code),
        )
        .route("/v1/live-sessions/{session_id}", get(get_live_session))
        .route(
            "/v1/live-sessions/{session_id}/status",
            patch(update_session_status),
        )
        .route(
            "/v1/live-sessions/{session_id}/safety",
            patch(update_safety),
        )
        .route(
            "/v1/live-sessions/{session_id}/cues",
            get(list_guidance_cues).post(create_guidance_cue),
        )
        .route(
            "/v1/live-sessions/{session_id}/messages",
            get(list_chat_messages).post(create_chat_message),
        )
        .route(
            "/v1/live-sessions/{session_id}/signal",
            get(get_signal_state),
        )
        .route(
            "/v1/live-sessions/{session_id}/signal/offer",
            post(upsert_signal_offer),
        )
        .route(
            "/v1/live-sessions/{session_id}/signal/answer",
            post(upsert_signal_answer),
        )
        .route(
            "/v1/live-sessions/{session_id}/signal/ice-candidates",
            post(add_ice_candidate),
        )
        .route("/v1/support-intents", post(create_support_intent))
        .layer(CorsLayer::permissive())
        .layer(TraceLayer::new_for_http())
        .with_state(state);

    let bind_addr = env::var("CONNECT_API_BIND").unwrap_or_else(|_| "localhost:8080".into());

    tracing::info!("starting connect api");
    let listener = tokio::net::TcpListener::bind(bind_addr.as_str())
        .await
        .expect("failed to bind api listener");

    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await
        .expect("api server failed");
}

async fn healthz() -> Json<HealthResponse> {
    Json(HealthResponse {
        status: "ok",
        service: "connect-api",
    })
}

async fn create_channel(
    State(state): State<AppState>,
    Json(payload): Json<CreateChannelRequest>,
) -> Result<(StatusCode, Json<Channel>), StatusCode> {
    let title = payload.title.trim();
    if title.is_empty() || title.chars().count() > 40 {
        return Err(StatusCode::BAD_REQUEST);
    }

    let channel_id = Uuid::new_v4();
    let channel_code = make_join_code(channel_id);
    let channel = Channel {
        channel_id,
        channel_link: make_channel_link(&channel_code),
        channel_code,
        title: title.to_owned(),
        support_enabled: payload.support_enabled,
    };

    state
        .channels
        .write()
        .await
        .insert(channel.channel_id, channel.clone());

    Ok((StatusCode::CREATED, Json(channel)))
}

async fn get_channel(
    State(state): State<AppState>,
    Path(channel_id): Path<Uuid>,
) -> Result<Json<Channel>, StatusCode> {
    let channels = state.channels.read().await;
    let channel = channels.get(&channel_id).ok_or(StatusCode::NOT_FOUND)?;

    Ok(Json(channel.clone()))
}

async fn get_channel_by_code(
    State(state): State<AppState>,
    Path(channel_code): Path<String>,
) -> Result<Json<Channel>, StatusCode> {
    let normalized_channel_code = channel_code.trim().to_ascii_uppercase();
    if normalized_channel_code.is_empty() {
        return Err(StatusCode::BAD_REQUEST);
    }

    let channels = state.channels.read().await;
    let channel = channels
        .values()
        .find(|channel| channel.channel_code == normalized_channel_code)
        .ok_or(StatusCode::NOT_FOUND)?;

    Ok(Json(channel.clone()))
}

async fn create_support_intent(
    State(state): State<AppState>,
    Json(payload): Json<CreateSupportIntentRequest>,
) -> Result<(StatusCode, Json<SupportIntent>), StatusCode> {
    if payload.channel_id.is_none() && payload.session_id.is_none() {
        return Err(StatusCode::BAD_REQUEST);
    }

    if let Some(channel_id) = payload.channel_id {
        let channels = state.channels.read().await;
        let channel = channels.get(&channel_id).ok_or(StatusCode::NOT_FOUND)?;
        if !channel.support_enabled {
            return Err(StatusCode::CONFLICT);
        }
    }

    if let Some(session_id) = payload.session_id {
        let sessions = state.sessions.read().await;
        let session = sessions.get(&session_id).ok_or(StatusCode::NOT_FOUND)?;

        if let (Some(request_channel_id), Some(session_channel_id)) =
            (payload.channel_id, session.channel_id)
        {
            if request_channel_id != session_channel_id {
                return Err(StatusCode::BAD_REQUEST);
            }
        }

        if payload.channel_id.is_none() {
            let Some(channel_id) = session.channel_id else {
                return Err(StatusCode::CONFLICT);
            };

            let channels = state.channels.read().await;
            let channel = channels.get(&channel_id).ok_or(StatusCode::NOT_FOUND)?;
            if !channel.support_enabled {
                return Err(StatusCode::CONFLICT);
            }
        }
    }

    let message = match payload.message {
        Some(message) if message.chars().count() <= 120 => Some(message),
        Some(_) => return Err(StatusCode::BAD_REQUEST),
        None => None,
    };

    let support_id = Uuid::new_v4();
    let intent = SupportIntent {
        support_id,
        channel_id: payload.channel_id,
        session_id: payload.session_id,
        tier: payload.tier,
        status: SupportStatus::Pending,
        message,
    };

    state
        .support_intents
        .write()
        .await
        .insert(intent.support_id, intent.clone());

    Ok((StatusCode::CREATED, Json(intent)))
}

async fn create_live_session(
    State(state): State<AppState>,
    Json(payload): Json<CreateLiveSessionRequest>,
) -> Result<(StatusCode, Json<LiveSession>), StatusCode> {
    if let Some(channel_id) = payload.channel_id {
        let channels = state.channels.read().await;
        if !channels.contains_key(&channel_id) {
            return Err(StatusCode::NOT_FOUND);
        }
    }

    let session_id = Uuid::new_v4();
    let join_code = make_join_code(session_id);
    let session = LiveSession {
        session_id,
        join_link: make_live_join_link(&join_code),
        join_code,
        channel_id: payload.channel_id,
        purpose: payload.purpose,
        source_mode: payload.source_mode,
        runner_vision_mode: payload.runner_vision_mode,
        status: SessionStatus::WaitingForSupporter,
        safety_state: SafetyState::CheckRequired,
        host_alias: payload.host_alias,
    };

    state
        .sessions
        .write()
        .await
        .insert(session.session_id, session.clone());

    Ok((StatusCode::CREATED, Json(session)))
}

fn make_join_code(session_id: Uuid) -> String {
    session_id
        .simple()
        .to_string()
        .chars()
        .take(12)
        .collect::<String>()
        .to_ascii_uppercase()
}

fn make_channel_link(channel_code: &str) -> String {
    format!("{}/channels/{}", public_app_base_url(), channel_code)
}

fn make_live_join_link(join_code: &str) -> String {
    format!("{}/join/live/{}", public_app_base_url(), join_code)
}

fn public_app_base_url() -> String {
    env::var("CONNECT_PUBLIC_APP_URL")
        .unwrap_or_else(|_| "connect://open".into())
        .trim_end_matches('/')
        .to_owned()
}

async fn get_live_session(
    State(state): State<AppState>,
    Path(session_id): Path<Uuid>,
) -> Result<Json<LiveSession>, StatusCode> {
    let sessions = state.sessions.read().await;
    let session = sessions.get(&session_id).ok_or(StatusCode::NOT_FOUND)?;

    Ok(Json(session.clone()))
}

async fn get_live_session_by_join_code(
    State(state): State<AppState>,
    Path(join_code): Path<String>,
) -> Result<Json<LiveSession>, StatusCode> {
    let normalized_join_code = join_code.trim().to_ascii_uppercase();
    if normalized_join_code.is_empty() {
        return Err(StatusCode::BAD_REQUEST);
    }

    let sessions = state.sessions.read().await;
    let session = sessions
        .values()
        .find(|session| session.join_code == normalized_join_code)
        .ok_or(StatusCode::NOT_FOUND)?;

    Ok(Json(session.clone()))
}

async fn update_safety(
    State(state): State<AppState>,
    Path(session_id): Path<Uuid>,
    Json(payload): Json<UpdateSafetyRequest>,
) -> Result<Json<SafetyResponse>, StatusCode> {
    let mut sessions = state.sessions.write().await;
    let session = sessions.get_mut(&session_id).ok_or(StatusCode::NOT_FOUND)?;
    session.safety_state = payload.safety_state.clone();

    Ok(Json(SafetyResponse {
        session_id,
        safety_state: payload.safety_state,
        reason: payload.reason,
    }))
}

async fn update_session_status(
    State(state): State<AppState>,
    Path(session_id): Path<Uuid>,
    Json(payload): Json<UpdateSessionStatusRequest>,
) -> Result<Json<LiveSession>, StatusCode> {
    if let Some(reason) = &payload.reason {
        if reason.chars().count() > 120 {
            return Err(StatusCode::BAD_REQUEST);
        }
    }

    let mut sessions = state.sessions.write().await;
    let session = sessions.get_mut(&session_id).ok_or(StatusCode::NOT_FOUND)?;
    session.status = payload.status;

    Ok(Json(session.clone()))
}

async fn list_guidance_cues(
    State(state): State<AppState>,
    Path(session_id): Path<Uuid>,
) -> Result<Json<Vec<GuidanceCueEvent>>, StatusCode> {
    ensure_live_session_exists(&state, session_id).await?;

    let cue_events = state.cue_events.read().await;
    Ok(Json(
        cue_events
            .get(&session_id)
            .cloned()
            .unwrap_or_else(Vec::new),
    ))
}

async fn create_guidance_cue(
    State(state): State<AppState>,
    Path(session_id): Path<Uuid>,
    Json(payload): Json<CreateGuidanceCueRequest>,
) -> Result<(StatusCode, Json<GuidanceCueEvent>), StatusCode> {
    ensure_live_session_exists(&state, session_id).await?;

    let mut cue_events = state.cue_events.write().await;
    let session_events = cue_events.entry(session_id).or_insert_with(Vec::new);
    let sequence = session_events
        .last()
        .map(|event| event.sequence + 1)
        .unwrap_or(1);
    let event = GuidanceCueEvent {
        cue_event_id: Uuid::new_v4(),
        session_id,
        sequence,
        cue: payload.cue,
        sender_role: payload.sender_role,
    };
    session_events.push(event.clone());
    if session_events.len() > 200 {
        session_events.remove(0);
    }

    if matches!(&event.cue, GuidanceCue::StopNow) {
        let mut sessions = state.sessions.write().await;
        let session = sessions.get_mut(&session_id).ok_or(StatusCode::NOT_FOUND)?;
        session.safety_state = SafetyState::StopNow;
    }

    Ok((StatusCode::CREATED, Json(event)))
}

async fn list_chat_messages(
    State(state): State<AppState>,
    Path(session_id): Path<Uuid>,
) -> Result<Json<Vec<LiveChatMessage>>, StatusCode> {
    ensure_live_session_exists(&state, session_id).await?;

    let chat_messages = state.chat_messages.read().await;
    Ok(Json(
        chat_messages
            .get(&session_id)
            .cloned()
            .unwrap_or_else(Vec::new),
    ))
}

async fn create_chat_message(
    State(state): State<AppState>,
    Path(session_id): Path<Uuid>,
    Json(payload): Json<CreateLiveChatMessageRequest>,
) -> Result<(StatusCode, Json<LiveChatMessage>), StatusCode> {
    ensure_live_session_exists(&state, session_id).await?;

    let body = payload.body.trim();
    if body.is_empty() || body.chars().count() > 280 {
        return Err(StatusCode::BAD_REQUEST);
    }

    let mut chat_messages = state.chat_messages.write().await;
    let session_messages = chat_messages.entry(session_id).or_insert_with(Vec::new);
    let sequence = session_messages
        .last()
        .map(|message| message.sequence + 1)
        .unwrap_or(1);
    let message = LiveChatMessage {
        message_id: Uuid::new_v4(),
        session_id,
        sequence,
        sender_role: payload.sender_role,
        body: body.to_owned(),
    };
    session_messages.push(message.clone());
    if session_messages.len() > 200 {
        session_messages.remove(0);
    }

    Ok((StatusCode::CREATED, Json(message)))
}

async fn get_signal_state(
    State(state): State<AppState>,
    Path(session_id): Path<Uuid>,
) -> Result<Json<SignalState>, StatusCode> {
    ensure_live_session_exists(&state, session_id).await?;

    let mut signal_states = state.signal_states.write().await;
    let signal_state = signal_states
        .entry(session_id)
        .or_insert_with(|| SignalState::new(session_id));

    Ok(Json(signal_state.clone()))
}

async fn upsert_signal_offer(
    State(state): State<AppState>,
    Path(session_id): Path<Uuid>,
    Json(payload): Json<UpsertSessionDescriptionRequest>,
) -> Result<Json<SignalState>, StatusCode> {
    ensure_live_session_exists(&state, session_id).await?;
    if !matches!(payload.sdp_type, SdpType::Offer) || payload.sdp.trim().is_empty() {
        return Err(StatusCode::BAD_REQUEST);
    }

    let mut signal_states = state.signal_states.write().await;
    let signal_state = signal_states
        .entry(session_id)
        .or_insert_with(|| SignalState::new(session_id));
    signal_state.offer = Some(SessionDescription {
        sdp_type: SdpType::Offer,
        sdp: payload.sdp,
    });
    signal_state.answer = None;
    signal_state.host_ice_candidates.clear();
    signal_state.supporter_ice_candidates.clear();

    Ok(Json(signal_state.clone()))
}

async fn upsert_signal_answer(
    State(state): State<AppState>,
    Path(session_id): Path<Uuid>,
    Json(payload): Json<UpsertSessionDescriptionRequest>,
) -> Result<Json<SignalState>, StatusCode> {
    ensure_live_session_exists(&state, session_id).await?;
    if !matches!(payload.sdp_type, SdpType::Answer) || payload.sdp.trim().is_empty() {
        return Err(StatusCode::BAD_REQUEST);
    }

    let mut signal_states = state.signal_states.write().await;
    let signal_state = signal_states
        .entry(session_id)
        .or_insert_with(|| SignalState::new(session_id));
    if signal_state.offer.is_none() {
        return Err(StatusCode::CONFLICT);
    }

    signal_state.answer = Some(SessionDescription {
        sdp_type: SdpType::Answer,
        sdp: payload.sdp,
    });

    let mut sessions = state.sessions.write().await;
    let session = sessions.get_mut(&session_id).ok_or(StatusCode::NOT_FOUND)?;
    session.status = SessionStatus::Connected;

    Ok(Json(signal_state.clone()))
}

async fn add_ice_candidate(
    State(state): State<AppState>,
    Path(session_id): Path<Uuid>,
    Json(payload): Json<AddIceCandidateRequest>,
) -> Result<Json<SignalState>, StatusCode> {
    ensure_live_session_exists(&state, session_id).await?;
    if payload.candidate.candidate.trim().is_empty() {
        return Err(StatusCode::BAD_REQUEST);
    }

    let mut signal_states = state.signal_states.write().await;
    let signal_state = signal_states
        .entry(session_id)
        .or_insert_with(|| SignalState::new(session_id));

    match payload.role {
        SignalRole::Host => signal_state.host_ice_candidates.push(payload.candidate),
        SignalRole::Supporter => signal_state
            .supporter_ice_candidates
            .push(payload.candidate),
    }

    Ok(Json(signal_state.clone()))
}

async fn ensure_live_session_exists(state: &AppState, session_id: Uuid) -> Result<(), StatusCode> {
    let sessions = state.sessions.read().await;
    if sessions.contains_key(&session_id) {
        Ok(())
    } else {
        Err(StatusCode::NOT_FOUND)
    }
}

async fn shutdown_signal() {
    let ctrl_c = async {
        tokio::signal::ctrl_c()
            .await
            .expect("failed to install Ctrl+C handler");
    };

    #[cfg(unix)]
    let terminate = async {
        tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
            .expect("failed to install signal handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {},
        _ = terminate => {},
    }
}
