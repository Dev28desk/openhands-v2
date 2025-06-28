import { DeskDev.aiParsedEvent } from ".";
import {
  UserMessageAction,
  AssistantMessageAction,
  DeskDev.aiAction,
  SystemMessageAction,
  CommandAction,
} from "./actions";
import {
  AgentStateChangeObservation,
  CommandObservation,
  ErrorObservation,
  MCPObservation,
  DeskDev.aiObservation,
} from "./observations";
import { StatusUpdate } from "./variances";

export const isDeskDev.aiAction = (
  event: DeskDev.aiParsedEvent,
): event is DeskDev.aiAction => "action" in event;

export const isDeskDev.aiObservation = (
  event: DeskDev.aiParsedEvent,
): event is DeskDev.aiObservation => "observation" in event;

export const isUserMessage = (
  event: DeskDev.aiParsedEvent,
): event is UserMessageAction =>
  isDeskDev.aiAction(event) &&
  event.source === "user" &&
  event.action === "message";

export const isAssistantMessage = (
  event: DeskDev.aiParsedEvent,
): event is AssistantMessageAction =>
  isDeskDev.aiAction(event) &&
  event.source === "agent" &&
  (event.action === "message" || event.action === "finish");

export const isErrorObservation = (
  event: DeskDev.aiParsedEvent,
): event is ErrorObservation =>
  isDeskDev.aiObservation(event) && event.observation === "error";

export const isCommandAction = (
  event: DeskDev.aiParsedEvent,
): event is CommandAction => isDeskDev.aiAction(event) && event.action === "run";

export const isAgentStateChangeObservation = (
  event: DeskDev.aiParsedEvent,
): event is AgentStateChangeObservation =>
  isDeskDev.aiObservation(event) && event.observation === "agent_state_changed";

export const isCommandObservation = (
  event: DeskDev.aiParsedEvent,
): event is CommandObservation =>
  isDeskDev.aiObservation(event) && event.observation === "run";

export const isFinishAction = (
  event: DeskDev.aiParsedEvent,
): event is AssistantMessageAction =>
  isDeskDev.aiAction(event) && event.action === "finish";

export const isSystemMessage = (
  event: DeskDev.aiParsedEvent,
): event is SystemMessageAction =>
  isDeskDev.aiAction(event) && event.action === "system";

export const isRejectObservation = (
  event: DeskDev.aiParsedEvent,
): event is DeskDev.aiObservation =>
  isDeskDev.aiObservation(event) && event.observation === "user_rejected";

export const isMcpObservation = (
  event: DeskDev.aiParsedEvent,
): event is MCPObservation =>
  isDeskDev.aiObservation(event) && event.observation === "mcp";

export const isStatusUpdate = (
  event: DeskDev.aiParsedEvent,
): event is StatusUpdate =>
  "status_update" in event && "type" in event && "id" in event;
