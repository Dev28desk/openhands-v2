import { useQuery } from "@tanstack/react-query";
import DeskDev.ai from "#/api/open-hands";

export const useUserRepositories = () =>
  useQuery({
    queryKey: ["repositories"],
    queryFn: DeskDev.ai.retrieveUserGitRepositories,
    staleTime: 1000 * 60 * 5, // 5 minutes
    gcTime: 1000 * 60 * 15, // 15 minutes
  });
