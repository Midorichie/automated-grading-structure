// frontend/src/types/gradeReview.ts
export interface GradeReview {
    reviewId: number;
    assignmentId: number;
    studentId: string;
    originalGrade: number;
    reason: string;
    status: 'PENDING' | 'APPROVED' | 'REJECTED';
    reviewerFeedback?: string;
    newGrade?: number;
    requestedAt: number;
    reviewedAt?: number;
}
