import { useQuery } from "@tanstack/react-query";
import DeskDev.ai from "#/api/open-hands";
import { Branch } from "#/types/git";

export const useRepositoryBranches = (repository: string | null) =>
  useQuery<Branch[]>({
    queryKey: ["repository", repository, "branches"],
    queryFn: async () => {
      if (!repository) return [];
      return DeskDev.ai.getRepositoryBranches(repository);
    },
    enabled: !!repository,
    staleTime: 1000 * 60 * 5, // 5 minutes
  });
