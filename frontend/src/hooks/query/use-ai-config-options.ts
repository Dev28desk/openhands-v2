import { useQuery } from "@tanstack/react-query";
import DeskDev.ai from "#/api/open-hands";

const fetchAiConfigOptions = async () => ({
  models: await DeskDev.ai.getModels(),
  agents: await DeskDev.ai.getAgents(),
  securityAnalyzers: await DeskDev.ai.getSecurityAnalyzers(),
});

export const useAIConfigOptions = () =>
  useQuery({
    queryKey: ["ai-config-options"],
    queryFn: fetchAiConfigOptions,
    staleTime: 1000 * 60 * 5, // 5 minutes
    gcTime: 1000 * 60 * 15, // 15 minutes
  });
