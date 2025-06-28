import { useMutation } from "@tanstack/react-query";
import DeskDev.ai from "#/api/open-hands";

export const useGetTrajectory = () =>
  useMutation({
    mutationFn: (cid: string) => DeskDev.ai.getTrajectory(cid),
  });
