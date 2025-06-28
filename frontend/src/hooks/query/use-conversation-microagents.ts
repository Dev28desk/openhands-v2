import { useQuery } from "@tanstack/react-query";
import DeskDev.ai from "#/api/open-hands";

interface UseConversationMicroagentsOptions {
  conversationId: string | undefined;
  enabled?: boolean;
}

export const useConversationMicroagents = ({
  conversationId,
  enabled = true,
}: UseConversationMicroagentsOptions) =>
  useQuery({
    queryKey: ["conversation", conversationId, "microagents"],
    queryFn: async () => {
      if (!conversationId) {
        throw new Error("No conversation ID provided");
      }
      const data = await DeskDev.ai.getMicroagents(conversationId);
      return data.microagents;
    },
    enabled: !!conversationId && enabled,
    staleTime: 1000 * 60 * 5, // 5 minutes
    gcTime: 1000 * 60 * 15, // 15 minutes
  });
