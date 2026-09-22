/**
 * CommerceAccessException
 *
 * Maps to the Constitution's error-category table, row AUTHORIZATION_ERROR.
 * Thrown on FLS/CRUD problems and on permission-set / permission-set-licence resolution
 * failures - notably the EC-03 guard, where a permission set API name cannot be resolved
 * against the target org and must NOT be assigned speculatively.
 *
 * In LWC, callers must re-throw this as an AuraHandledException (Constitution, Error Handling).
 */
public class CommerceAccessException extends Exception {}
