// frontend/src/hooks/useGradeReview.ts
import { useState, useCallback } from 'react';
import { useConnect } from '@stacks/connect-react';
import { StacksNetwork, StacksMocknet } from '@stacks/network';
import { 
    callReadOnlyFunction,
    contractPrincipalCV,
    uintCV,
    stringAsciiCV 
} from '@stacks/transactions';

export const useGradeReview = () => {
    const { doContractCall } = useConnect();
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);

    const requestReview = useCallback(async (
        assignmentId: number,
        originalGrade: number,
        reason: string
    ) => {
        setLoading(true);
        try {
            await doContractCall({
                network: new StacksMocknet(),
                contractAddress: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
                contractName: 'grade-review',
                functionName: 'request-grade-review',
                functionArgs: [
                    uintCV(assignmentId),
                    uintCV(originalGrade),
                    stringAsciiCV(reason)
                ],
                onFinish: (data) => {
                    console.log('Review requested:', data);
                },
                onCancel: () => {
                    setError('Transaction cancelled');
                }
            });
        } catch (err) {
            setError(err.message);
        } finally {
            setLoading(false);
        }
    }, [doContractCall]);

    return { requestReview, loading, error };
};
