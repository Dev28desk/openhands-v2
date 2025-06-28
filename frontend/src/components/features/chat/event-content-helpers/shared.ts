import { DeskDev.aiAction } from "#/types/core/actions";
import { DeskDev.aiObservation } from "#/types/core/observations";

export const MAX_CONTENT_LENGTH = 1000;

export const getDefaultEventContent = (
  event: DeskDev.aiAction | DeskDev.aiObservation,
): string => `\`\`\`json\n${JSON.stringify(event, null, 2)}\n\`\`\``;
