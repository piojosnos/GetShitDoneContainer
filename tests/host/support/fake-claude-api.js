// Scripted fake Anthropic Messages API for tests. Node core modules only.
// - Used by tests/host/h18-scope-and-deny.sh (inside the test container) and by
//   tests/selftest/bundle/fake-api.sh (in the dev sandbox). Point Claude at it with
//   ANTHROPIC_BASE_URL=http://127.0.0.1:<port> and a dummy ANTHROPIC_API_KEY.
// - H18_PORT: port to listen on (default 8799). Listens on 127.0.0.1 only.
// - H18_SCRIPT: path to a JSON file holding an array of {name, input}; reply N is the Nth tool call.
//   After the last entry the reply is a text block "done", which ends the Claude run.
// - H18_LOG: file that gets one line per main-loop request: step=<n> always=<yes|no> scoped=<yes|no>.
// - H18_MARK_ALWAYS, H18_MARK_SCOPED: texts looked up in the raw request body; yes means present.
// - The step number is the count of tool_result blocks Claude has posted back so far.
// - A request with more than 3 tools is a main-loop request; every other request gets a small reply.
// - Tied to the streaming wire format of the pinned Claude Code; it exits by itself after 120 seconds.
const http = require("http");
const fs = require("fs");

const port = parseInt(process.env.H18_PORT || "8799", 10);
const scriptPath = process.env.H18_SCRIPT;
const logPath = process.env.H18_LOG;
const markAlways = process.env.H18_MARK_ALWAYS || "";
const markScoped = process.env.H18_MARK_SCOPED || "";

let script = [];
if (scriptPath) {
  script = JSON.parse(fs.readFileSync(scriptPath, "utf8"));
}

function sendEvent(res, eventName, data) {
  res.write("event: " + eventName + "\ndata: " + JSON.stringify(data) + "\n\n");
}

function yesNo(isPresent) {
  if (isPresent) {
    return "yes";
  }
  return "no";
}

function countToolResults(parsed) {
  let count = 0;

  for (const message of parsed.messages || []) {
    if (!Array.isArray(message.content)) {
      continue;
    }
    for (const block of message.content) {
      if (block.type === "tool_result") {
        count += 1;
      }
    }
  }

  return count;
}

const server = http.createServer((req, res) => {
  let body = "";

  req.on("data", (chunk) => {
    body += chunk;
  });
  req.on("end", () => {
    let parsed = {};
    if (body) {
      parsed = JSON.parse(body);
    }

    if (!req.url.startsWith("/v1/messages") || req.url.includes("count_tokens") || !parsed.stream) {
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify({
        input_tokens: 10, id: "m", type: "message", role: "assistant", model: "m",
        content: [{ type: "text", text: "ok" }], stop_reason: "end_turn",
        usage: { input_tokens: 5, output_tokens: 1 }
      }));

      return;
    }

    const step = countToolResults(parsed);
    const isMainLoop = (parsed.tools || []).length > 3;
    let tool;
    if (isMainLoop) {
      tool = script[step];
    }

    if (isMainLoop && logPath) {
      const logLine = "step=" + step
        + " always=" + yesNo(markAlways !== "" && body.includes(markAlways))
        + " scoped=" + yesNo(markScoped !== "" && body.includes(markScoped)) + "\n";
      fs.appendFileSync(logPath, logLine);
    }

    res.writeHead(200, { "content-type": "text/event-stream" });
    sendEvent(res, "message_start", {
      type: "message_start",
      message: {
        id: "m" + step, type: "message", role: "assistant", model: parsed.model, content: [],
        stop_reason: null, usage: { input_tokens: 10, output_tokens: 1 }
      }
    });
    if (tool) {
      sendEvent(res, "content_block_start", {
        type: "content_block_start", index: 0,
        content_block: { type: "tool_use", id: "t" + step, name: tool.name, input: {} }
      });
      sendEvent(res, "content_block_delta", {
        type: "content_block_delta", index: 0,
        delta: { type: "input_json_delta", partial_json: JSON.stringify(tool.input) }
      });
    } else {
      sendEvent(res, "content_block_start", {
        type: "content_block_start", index: 0, content_block: { type: "text", text: "" }
      });
      sendEvent(res, "content_block_delta", {
        type: "content_block_delta", index: 0, delta: { type: "text_delta", text: "done" }
      });
    }
    sendEvent(res, "content_block_stop", { type: "content_block_stop", index: 0 });
    let stopReason = "end_turn";
    if (tool) {
      stopReason = "tool_use";
    }
    sendEvent(res, "message_delta", {
      type: "message_delta", delta: { stop_reason: stopReason, stop_sequence: null }, usage: { output_tokens: 5 }
    });
    sendEvent(res, "message_stop", { type: "message_stop" });
    res.end();
  });
});

server.listen(port, "127.0.0.1");
setTimeout(() => {
  process.exit(0);
}, 120000);
