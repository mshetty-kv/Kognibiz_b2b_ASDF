/**
 * CommerceBusinessException
 *
 * Maps to the Constitution's error-category table, row BUSINESS_ERROR.
 * Thrown when a commerce rule or a BR-01 dependency-order precondition is violated -
 * for example a seeder finding that its prerequisite chain step has not been run yet.
 *
 * In LWC, callers must re-throw this as an AuraHandledException so the buyer never sees
 * a raw stack trace (Constitution, Error Handling).
 */
public class CommerceBusinessException extends Exception {}
