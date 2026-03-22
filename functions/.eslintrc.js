module.exports = {
  root: true,
  parser: "@typescript-eslint/parser",
  parserOptions: { project: null },
  plugins: ["@typescript-eslint"],
  extends: [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended"
  ],
  env: {
    node: true,
    es2020: true
  },
  ignorePatterns: ["lib/**"]
};