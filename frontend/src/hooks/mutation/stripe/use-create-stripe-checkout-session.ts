import { useMutation } from "@tanstack/react-query";
import DeskDev.ai from "#/api/open-hands";

export const useCreateStripeCheckoutSession = () =>
  useMutation({
    mutationFn: async (variables: { amount: number }) => {
      const redirectUrl = await DeskDev.ai.createCheckoutSession(
        variables.amount,
      );
      window.location.href = redirectUrl;
    },
  });
