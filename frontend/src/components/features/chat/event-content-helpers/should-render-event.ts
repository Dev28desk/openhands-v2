import { DeskDev.aiAction } from "#/types/core/actions";
import { DeskDev.aiEventType } from "#/types/core/base";
import {
  isCommandAction,
  isCommandObservation,
  isDeskDev.aiAction,
  isDeskDev.aiObservation,
} from "#/types/core/guards";
import { DeskDev.aiObservation } from "#/types/core/observations";

const COMMON_NO_RENDER_LIST: DeskDev.aiEventType[] = [
  "system",
  "agent_state_changed",
  "change_agent_state",
];

const ACTION_NO_RENDER_LIST: DeskDev.aiEventType[] = ["recall"];

export const shouldRenderEvent = (
  event: DeskDev.aiAction | DeskDev.aiObservation,
) => {
  if (isDeskDev.aiAction(event)) {
    if (isCommandAction(event) && event.source === "user") {
      // For user commands, we always hide them from the chat interface
      return false;
    }

    const noRenderList = COMMON_NO_RENDER_LIST.concat(ACTION_NO_RENDER_LIST);
    return !noRenderList.includes(event.action);
  }

  if (isDeskDev.aiObservation(event)) {
    if (isCommandObservation(event) && event.source === "user") {
      // For user commands, we always hide them from the chat interface
      return false;
    }

    return !COMMON_NO_RENDER_LIST.includes(event.observation);
  }

  return true;
};
