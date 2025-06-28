export type DeskDev.aiEventType =
  | "message"
  | "system"
  | "agent_state_changed"
  | "change_agent_state"
  | "run"
  | "read"
  | "write"
  | "edit"
  | "run_ipython"
  | "delegate"
  | "browse"
  | "browse_interactive"
  | "reject"
  | "think"
  | "finish"
  | "error"
  | "recall"
  | "mcp"
  | "call_tool_mcp"
  | "user_rejected";

export type DeskDev.aiSourceType = "agent" | "user" | "environment";

interface DeskDev.aiBaseEvent {
  id: number;
  source: DeskDev.aiSourceType;
  message: string;
  timestamp: string; // ISO 8601
}

export interface DeskDev.aiActionEvent<T extends DeskDev.aiEventType>
  extends DeskDev.aiBaseEvent {
  action: T;
  args: Record<string, unknown>;
}

export interface DeskDev.aiObservationEvent<T extends DeskDev.aiEventType>
  extends DeskDev.aiBaseEvent {
  cause: number;
  observation: T;
  content: string;
  extras: Record<string, unknown>;
}
