import { useQuery } from "@tanstack/react-query";
import React from "react";
import posthog from "posthog-js";
import DeskDev.ai from "#/api/open-hands";
import { DEFAULT_SETTINGS } from "#/services/settings";
import { useIsOnTosPage } from "#/hooks/use-is-on-tos-page";
import { Settings } from "#/types/settings";
import { useIsAuthed } from "./use-is-authed";

const getSettingsQueryFn = async (): Promise<Settings> => {
  const apiSettings = await DeskDev.ai.getSettings();

  return {
    LLM_MODEL: apiSettings.llm_model,
    LLM_BASE_URL: apiSettings.llm_base_url,
    AGENT: apiSettings.agent,
    LANGUAGE: apiSettings.language,
    CONFIRMATION_MODE: apiSettings.confirmation_mode,
    SECURITY_ANALYZER: apiSettings.security_analyzer,
    LLM_API_KEY_SET: apiSettings.llm_api_key_set,
    SEARCH_API_KEY_SET: apiSettings.search_api_key_set,
    REMOTE_RUNTIME_RESOURCE_FACTOR: apiSettings.remote_runtime_resource_factor,
    PROVIDER_TOKENS_SET: apiSettings.provider_tokens_set,
    ENABLE_DEFAULT_CONDENSER: apiSettings.enable_default_condenser,
    ENABLE_SOUND_NOTIFICATIONS: apiSettings.enable_sound_notifications,
    ENABLE_PROACTIVE_CONVERSATION_STARTERS:
      apiSettings.enable_proactive_conversation_starters,
    USER_CONSENTS_TO_ANALYTICS: apiSettings.user_consents_to_analytics,
    SEARCH_API_KEY: apiSettings.search_api_key || "",
    MAX_BUDGET_PER_TASK: apiSettings.max_budget_per_task,
    EMAIL: apiSettings.email || "",
    EMAIL_VERIFIED: apiSettings.email_verified,
    MCP_CONFIG: apiSettings.mcp_config,
    IS_NEW_USER: false,
  };
};

export const useSettings = () => {
  const isOnTosPage = useIsOnTosPage();
  const { data: userIsAuthenticated } = useIsAuthed();

  const query = useQuery({
    queryKey: ["settings"],
    queryFn: getSettingsQueryFn,
    // Only retry if the error is not a 404 because we
    // would want to show the modal immediately if the
    // settings are not found
    retry: (_, error) => error.status !== 404,
    refetchOnWindowFocus: false,
    staleTime: 1000 * 60 * 5, // 5 minutes
    gcTime: 1000 * 60 * 15, // 15 minutes
    enabled: !isOnTosPage && !!userIsAuthenticated,
    meta: {
      disableToast: true,
    },
  });

  React.useEffect(() => {
    if (query.isFetched && query.data?.LLM_API_KEY_SET) {
      posthog.capture("user_activated");
    }
  }, [query.data?.LLM_API_KEY_SET, query.isFetched]);

  // We want to return the defaults if the settings aren't found so the user can still see the
  // options to make their initial save. We don't set the defaults in `initialData` above because
  // that would prepopulate the data to the cache and mess with expectations. Read more:
  // https://tanstack.com/query/latest/docs/framework/react/guides/initial-query-data#using-initialdata-to-prepopulate-a-query
  if (query.error?.status === 404) {
    // Create a new object with only the properties we need, avoiding rest destructuring
    return {
      data: DEFAULT_SETTINGS,
      error: query.error,
      isError: query.isError,
      isLoading: query.isLoading,
      isFetching: query.isFetching,
      isFetched: query.isFetched,
      isSuccess: query.isSuccess,
      status: query.status,
      fetchStatus: query.fetchStatus,
      refetch: query.refetch,
    };
  }

  return query;
};
