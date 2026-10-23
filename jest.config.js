const { jestConfig } = require('@salesforce/sfdx-lwc-jest/config');

module.exports = {
    ...jestConfig,
    moduleNameMapper: {
        ...(jestConfig.moduleNameMapper || {}),
        // CSS-only shared module: the default resolver only looks for a .js entry point.
        '^c/officeDepotTokens$': '<rootDir>/force-app/main/default/lwc/officeDepotTokens/officeDepotTokens.css'
    },
    modulePathIgnorePatterns: ['<rootDir>/.localdevserver']
};
