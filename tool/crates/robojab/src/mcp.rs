use crate::*;

/// What a client is told at the handshake: the loop and the grammar.
const INSTRUCTIONS: &str = "robojab runs one Jab machine. Play it a move at a time: call `send` with a \
line of commands, let it run for the wait, and read the frame that comes back - whether the machine \
still runs, its faults resolved to their routines, the UART's and the debug channel's new lines, the \
API's new bytes, the sound's level over the span, and the screen reduced to a glance as an image. \
Call `send` again, until the frame's `exit` is set (the program ended, faulted, or hit the bound) or \
you call `exit`. An empty line only looks.\n\
Commands, separated by `;`:\n\
  pad stick <left|right> <x> <y>   throws -1 to 1, y up is +1; the stick stays until moved again\n\
  pad trigger <left|right> <pull>  0 to 1\n\
  pad hat <x> <y>                  -1, 0, or 1\n\
  pad button <name> <down|up>      names: south east north west tl tr tl2 tr2 select start mode thumbl thumbr, or a code 304-335\n\
  pad tap <name> [hold_ms]         press and release, 100 ms unless given\n\
  pad rest                         every axis centred\n\
  pad raw <type> <code> <value>... evdev events outright, in one report, what a real device sends\n\
  key <qemu key name> [hold_ms]    the keyboard through QEMU's monitor, e.g. key w 300\n\
  api send <hex>                   bytes into the API port\n\
  wait <ms>                        pause mid-line\n\
  restart                          a fresh machine from the plan\n\
  quit                             end the machine (the frame then reports exit)\n\
The frame's `api` carries the program's bytes since the last frame as hex, or as records when \
`record_size` is given. `screen` is reduced by `divisor` (4 unless given) and JPEG-compressed at \
`quality` (40); ask for a divisor of 2 and quality 70 to read text. Faults are UART lines starting \
`jab: `; a frame with a fault is the evidence to keep.";

/// The harness as an MCP server over stdio: two tools, `send` and
/// `exit`, around one machine started on the first call.
#[derive(Clone)]
pub(crate) struct Robo {
    driver: Arc<Mutex<Driver>>,
    tool_router: r::mcp::ToolRouter<Robo>,
}

/// A move: commands, the wait, and how to look afterwards.
#[derive(serde::Deserialize, schemars::JsonSchema)]
pub(crate) struct SendParams {
    /// Commands for the machine, separated by `;`, run in order before the wait; empty to only look.
    #[serde(default)]
    pub(crate) line: String,
    /// Milliseconds the machine runs after the commands before the frame is taken; 500 unless given.
    pub(crate) wait_ms: Option<u64>,
    /// Whether the frame carries the screen; true unless given.
    pub(crate) screen: Option<bool>,
    /// The screen's reduction: each side divided by this, each pixel the mean of its block; 4 unless given.
    pub(crate) divisor: Option<u32>,
    /// The screen's JPEG quality, 1 to 100; 40 unless given.
    pub(crate) quality: Option<u8>,
    /// Cut the API's new bytes into records of this many bytes, each as hex, numbered from the first ever sent.
    pub(crate) record_size: Option<usize>,
}

#[r::mcp::tool_router(router = robo_router, vis = "pub(crate)")]
impl Robo {
    pub(crate) fn new(driver: Driver) -> Robo {
        Robo { driver: Arc::new(Mutex::new(driver)), tool_router: Self::robo_router() }
    }

    #[r::mcp::tool(description = "Play one move: run the commands, let the machine run for the wait, and return the frame - status, faults, UART, debug, API bytes, sound level, and the screen as an image. Call it again and again; an empty line only looks.")]
    pub(crate) async fn send(&self, r::mcp::Parameters(p): r::mcp::Parameters<SendParams>) -> r::mcp::CallToolResult {
        let driver = self.driver.clone();
        let outcome = tokio::task::spawn_blocking(move || -> RoboResult<Frame> {
            let mut driver = lock(&driver);
            let results = driver.line(&p.line);
            thread::sleep(Duration::from_millis(p.wait_ms.unwrap_or(500)));
            let look = Look {
                screen: p.screen.unwrap_or(true),
                divisor: p.divisor.unwrap_or(4).max(1),
                quality: p.quality.unwrap_or(40).clamp(1, 100),
                format: Format::Jpeg,
                record_size: p.record_size,
            };
            let mut frame = driver.frame(&look)?;
            frame.value["results"] = serde_json::Value::Array(results);
            Ok(frame)
        })
        .await;
        reply(outcome)
    }

    #[r::mcp::tool(description = "End the machine and return the last frame: the exit code, the faults resolved, and what the UART said last.")]
    pub(crate) async fn exit(&self) -> r::mcp::CallToolResult {
        let driver = self.driver.clone();
        let outcome = tokio::task::spawn_blocking(move || -> RoboResult<Frame> {
            let mut driver = lock(&driver);
            let code = driver.quit()?;
            let look = Look { screen: false, ..Look::default() };
            let mut frame = driver.frame(&look)?;
            frame.value["exit"] = serde_json::Value::from(code);
            Ok(frame)
        })
        .await;
        reply(outcome)
    }
}

#[r::mcp::tool_handler(router = self.tool_router)]
impl r::mcp::ServerHandler for Robo {
    fn get_info(&self) -> r::mcp::ServerConfig {
        r::mcp::ServerConfig::new(r::mcp::ServerCapabilities::builder().enable_tools().build())
            .with_server_info(r::mcp::Implementation::new("robojab", env!("CARGO_PKG_VERSION")))
            .with_instructions(INSTRUCTIONS)
    }
}

/// A frame as a tool result: its record as text and as the structured
/// content, the screen as an image block; a failure as an error result.
fn reply(outcome: Result<RoboResult<Frame>, tokio::task::JoinError>) -> r::mcp::CallToolResult {
    let frame = match outcome {
        Ok(Ok(frame)) => frame,
        Ok(Err(error)) => return r::mcp::CallToolResult::error(vec![r::mcp::ContentBlock::text(error.to_string())]),
        Err(error) => return r::mcp::CallToolResult::error(vec![r::mcp::ContentBlock::text(error.to_string())]),
    };
    let mut content = vec![r::mcp::ContentBlock::text(frame.value.to_string())];
    if let Some(shot) = &frame.shot {
        content.push(r::mcp::ContentBlock::image(r::b64::STANDARD.encode(&shot.bytes), shot.format.mime()));
    }
    let mut result = r::mcp::CallToolResult::success(content);
    result.structured_content = Some(frame.value);
    result
}

/// The server run over stdio until the client goes; the machine ended after.
pub(crate) fn serve_mcp(driver: Driver) -> RoboResult<()> {
    let runtime = tokio::runtime::Builder::new_multi_thread().enable_all().build().map_err(RoboError::io("the runtime"))?;
    let robo = Robo::new(driver);
    let driver = robo.driver.clone();
    let outcome = runtime.block_on(async {
        let service = robo.serve(r::mcp::stdio()).await.map_err(|error| RoboError::Machine(format!("mcp: {error}")))?;
        service.waiting().await.map_err(|error| RoboError::Machine(format!("mcp: {error}")))?;
        Ok(())
    });
    let _ = lock(&driver).quit();
    outcome
}
