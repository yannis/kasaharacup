import globals from 'globals';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import js from '@eslint/js';
import { FlatCompat } from '@eslint/eslintrc';

const filename = fileURLToPath(import.meta.url);
const dirname = path.dirname(filename);
const compat = new FlatCompat({
  baseDirectory: dirname,
  recommendedConfig: js.configs.recommended,
  allConfig: js.configs.all,
});

export default [{
  ignores: ['node_modules/**', 'app/assets/builds/*.js', 'vendor/**', 'coverage/**'],
}, ...compat.extends('airbnb-base'), {
  languageOptions: {
    globals: {
      ...globals.browser,
    },

    ecmaVersion: 13,
    sourceType: 'module',
  },

  rules: {
    'max-len': ['error', {
      code: 120,
    }],

    'class-methods-use-this': 'off',
    'no-alert': 'off',
  },
}];
