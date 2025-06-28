import { useQuery } from "@tanstack/react-query";
import DeskDev.ai from "#/api/open-hands";
import { useIsAuthed } from "./use-is-authed";

export const useUserConversations = () => {
  const { data: userIsAuthenticated } = useIsAuthed();

  return useQuery({
    queryKey: ["user", "conversations"],
    queryFn: DeskDev.ai.getUserConversations,
    enabled: !!userIsAuthenticated,
  });
};
