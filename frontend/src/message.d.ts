import { PayloadAction } from "@reduxjs/toolkit";
import { DeskDev.aiObservation } from "./types/core/observations";
import { DeskDev.aiAction } from "./types/core/actions";

export type Message = {
  sender: "user" | "assistant";
  content: string;
  timestamp: string;
  imageUrls?: string[];
  type?: "thought" | "error" | "action";
  success?: boolean;
  pending?: boolean;
  translationID?: string;
  eventID?: number;
  observation?: PayloadAction<DeskDev.aiObservation>;
  action?: PayloadAction<DeskDev.aiAction>;
};
