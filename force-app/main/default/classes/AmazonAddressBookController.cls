/**
 * B2B-ADDR-001 - Amazon-style address book for the B2B Commerce LWR "My Account > Addresses" page.
 *
 * Every read and write goes through the standard Commerce Buyer Experience Connect API
 * (ConnectApi.CommerceBuyerExperience.*CommerceAccountAddress), which persists to the standard
 * ContactPointAddress object and applies the platform's own buyer permission, sharing and
 * default-address rules. No SOQL or DML touches ContactPointAddress directly.
 *
 * The store and the account are derived from the runtime context (current Network and the
 * running user's Contact), never from client input, so a buyer cannot address another account.
 */
public with sharing class AmazonAddressBookController {
    private static final Set<String> ADDRESS_TYPES = new Set<String>{ 'Billing', 'Shipping' };
    private static final Integer PAGE_SIZE = 100;

    /** One address card. */
    public class AddressDto {
        @AuraEnabled public String addressId;
        @AuraEnabled public String addressType;
        @AuraEnabled public Boolean isDefault;
        @AuraEnabled public String name;
        @AuraEnabled public String phoneNumber;
        @AuraEnabled public String street;
        @AuraEnabled public String city;
        @AuraEnabled public String region;
        @AuraEnabled public String regionCode;
        @AuraEnabled public String postalCode;
        @AuraEnabled public String country;
        @AuraEnabled public String countryCode;
    }

    /** Country with its dependent states, for the form dropdowns. */
    public class CountryOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public List<Option> states = new List<Option>();
    }

    public class Option {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public Option(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    /** Form payload from the LWC. */
    public class AddressInput {
        @AuraEnabled public String addressId { get; set; }
        @AuraEnabled public String addressType { get; set; }
        @AuraEnabled public Boolean isDefault { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String phoneNumber { get; set; }
        @AuraEnabled public String street { get; set; }
        @AuraEnabled public String city { get; set; }
        @AuraEnabled public String regionCode { get; set; }
        @AuraEnabled public String postalCode { get; set; }
        @AuraEnabled public String countryCode { get; set; }
    }

    @AuraEnabled
    public static List<AddressDto> getAddresses() {
        Context ctx = resolveContext();
        try {
            ConnectApi.CommerceAddressCollection result = ConnectApi.CommerceBuyerExperience.getCommerceAccountAddress(
                ctx.webStoreId,
                ctx.accountId,
                false,
                new List<String>(ADDRESS_TYPES),
                null,
                null,
                PAGE_SIZE,
                ConnectApi.CommerceAddressSort.CreatedDateDesc
            );
            List<AddressDto> addresses = new List<AddressDto>();
            if (result != null && result.items != null) {
                for (ConnectApi.CommerceAddressOutput item : result.items) {
                    addresses.add(toDto(item));
                }
            }
            return addresses;
        } catch (Exception ex) {
            throw userSafe(ex);
        }
    }

    @AuraEnabled
    public static AddressDto saveAddress(AddressInput address) {
        validate(address);
        Context ctx = resolveContext();
        ConnectApi.CommerceAddressInput payload = toPayload(address);
        try {
            ConnectApi.CommerceAddressOutput saved = String.isBlank(address.addressId)
                ? ConnectApi.CommerceBuyerExperience.createCommerceAccountAddress(ctx.webStoreId, ctx.accountId, payload)
                : ConnectApi.CommerceBuyerExperience.updateCommerceAccountAddress(
                      ctx.webStoreId,
                      ctx.accountId,
                      address.addressId,
                      payload
                  );
            return toDto(saved);
        } catch (Exception ex) {
            throw userSafe(ex);
        }
    }

    @AuraEnabled
    public static void removeAddress(String addressId) {
        if (String.isBlank(addressId) || !(addressId instanceof Id)) {
            throw new AuraHandledException(System.Label.AmzAddr_ErrorInvalidRequest);
        }
        Context ctx = resolveContext();
        try {
            ConnectApi.CommerceBuyerExperience.deleteCommerceAccountAddress(ctx.webStoreId, ctx.accountId, addressId);
        } catch (Exception ex) {
            throw userSafe(ex);
        }
    }

    /** Countries and dependent states from the org's State and Country/Territory picklists. */
    @AuraEnabled(cacheable=true)
    public static List<CountryOption> getCountryOptions() {
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.ContactPointAddress.fields.getMap();
        List<CountryOption> countries = new List<CountryOption>();
        List<Schema.PicklistEntry> countryEntries = fields.get('CountryCode').getDescribe().getPicklistValues();
        for (Schema.PicklistEntry entry : countryEntries) {
            if (entry.isActive()) {
                CountryOption country = new CountryOption();
                country.label = entry.getLabel();
                country.value = entry.getValue();
                countries.add(country);
            }
        }
        attachStates(countries, countryEntries, fields.get('StateCode').getDescribe().getPicklistValues());
        return countries;
    }

    // ---------------------------------------------------------------- private helpers

    private class Context {
        String webStoreId;
        String accountId;
    }

    private class PicklistEntryJson {
        String validFor;
    }

    private static Context resolveContext() {
        Id networkId = Network.getNetworkId();
        List<User> users = [SELECT Contact.AccountId FROM User WHERE Id = :UserInfo.getUserId() WITH USER_MODE LIMIT 1];
        String accountId = users.isEmpty() || users[0].Contact == null ? null : users[0].Contact.AccountId;
        if (networkId == null || accountId == null) {
            throw new AuraHandledException(System.Label.AmzAddr_ErrorNoContext);
        }
        List<WebStoreNetwork> links = [
            SELECT WebStoreId
            FROM WebStoreNetwork
            WHERE NetworkId = :networkId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (links.isEmpty()) {
            throw new AuraHandledException(System.Label.AmzAddr_ErrorNoContext);
        }
        Context ctx = new Context();
        ctx.webStoreId = links[0].WebStoreId;
        ctx.accountId = accountId;
        return ctx;
    }

    private static void validate(AddressInput address) {
        Boolean invalid =
            address == null ||
            !ADDRESS_TYPES.contains(address.addressType) ||
            String.isBlank(address.name) ||
            String.isBlank(address.street) ||
            String.isBlank(address.city) ||
            String.isBlank(address.postalCode) ||
            String.isBlank(address.countryCode) ||
            (String.isNotBlank(address.addressId) && !(address.addressId instanceof Id));
        if (invalid) {
            throw new AuraHandledException(System.Label.AmzAddr_ErrorInvalidRequest);
        }
    }

    private static ConnectApi.CommerceAddressInput toPayload(AddressInput address) {
        ConnectApi.CommerceAddressInput payload = new ConnectApi.CommerceAddressInput();
        payload.addressType = address.addressType;
        payload.isDefault = address.isDefault == true;
        payload.name = address.name.trim();
        payload.phoneNumber = String.isBlank(address.phoneNumber) ? null : address.phoneNumber.trim();
        payload.street = address.street.trim();
        payload.city = address.city.trim();
        payload.region = String.isBlank(address.regionCode) ? null : address.regionCode; // ISO state code (API 58+)
        payload.postalCode = address.postalCode.trim();
        payload.country = address.countryCode; // ISO country code (API 58+)
        return payload;
    }

    private static AddressDto toDto(ConnectApi.CommerceAddressOutput item) {
        AddressDto dto = new AddressDto();
        dto.addressId = item.addressId;
        dto.addressType = item.addressType;
        dto.isDefault = item.isDefault == true;
        dto.name = item.name;
        dto.phoneNumber = item.phoneNumber;
        dto.street = item.street;
        dto.city = item.city;
        dto.region = item.region;
        dto.regionCode = item.region;
        dto.postalCode = item.postalCode;
        dto.country = item.country;
        dto.countryCode = item.country;
        return dto;
    }

    /** Decodes the dependent-picklist validFor bitmap once per state, not once per country pair. */
    private static void attachStates(
        List<CountryOption> countries,
        List<Schema.PicklistEntry> countryEntries,
        List<Schema.PicklistEntry> stateEntries
    ) {
        Map<Integer, CountryOption> byControllingIndex = new Map<Integer, CountryOption>();
        Map<String, CountryOption> byValue = new Map<String, CountryOption>();
        for (CountryOption country : countries) {
            byValue.put(country.value, country);
        }
        for (Integer index = 0; index < countryEntries.size(); index++) {
            CountryOption country = byValue.get(countryEntries[index].getValue());
            if (country != null) {
                byControllingIndex.put(index, country);
            }
        }
        for (Schema.PicklistEntry state : stateEntries) {
            if (!state.isActive()) {
                continue;
            }
            PicklistEntryJson parsed = (PicklistEntryJson) JSON.deserialize(JSON.serialize(state), PicklistEntryJson.class);
            if (String.isBlank(parsed.validFor)) {
                continue;
            }
            Blob bitmap = EncodingUtil.base64Decode(parsed.validFor);
            String hex = EncodingUtil.convertToHex(bitmap);
            for (Integer byteIndex = 0; byteIndex < hex.length() / 2; byteIndex++) {
                Integer value = hexToInt(hex.substring(byteIndex * 2, byteIndex * 2 + 2));
                if (value == 0) {
                    continue;
                }
                for (Integer bit = 0; bit < 8; bit++) {
                    if ((value & (128 >> bit)) != 0) {
                        CountryOption country = byControllingIndex.get(byteIndex * 8 + bit);
                        if (country != null) {
                            country.states.add(new Option(state.getLabel(), state.getValue()));
                        }
                    }
                }
            }
        }
    }

    private static Integer hexToInt(String hexPair) {
        String digits = '0123456789abcdef';
        return digits.indexOf(hexPair.substring(0, 1)) * 16 + digits.indexOf(hexPair.substring(1, 2));
    }

    private static AuraHandledException userSafe(Exception ex) {
        if (ex instanceof AuraHandledException) {
            return (AuraHandledException) ex;
        }
        String message = ex instanceof ConnectApi.ConnectApiException ? ex.getMessage() : System.Label.AmzAddr_ErrorGeneric;
        AuraHandledException safe = new AuraHandledException(message);
        safe.setMessage(message);
        return safe;
    }
}
