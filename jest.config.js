/** @type {import('ts-jest/dist/types').InitialOptionsTsJest} */
export default {
  preset: 'ts-jest',
  testPathIgnorePatterns: ["<rootDir>/build/", "<rootDir>/node_modules/"],
  testEnvironment: 'node',
};
