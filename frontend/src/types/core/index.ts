import { DeskDev.aiAction } from "./actions";
import { DeskDev.aiObservation } from "./observations";
import { DeskDev.aiVariance } from "./variances";

export type DeskDev.aiParsedEvent =
  | DeskDev.aiAction
  | DeskDev.aiObservation
  | DeskDev.aiVariance;
