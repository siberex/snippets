#!/usr/bin/env node

import { build } from 'esbuild';

build({
  entryPoints: ['make-static-handlers.ts'],
  outfile: 'dist/main.js',
  logLevel: 'info',
  charset: 'utf8',
  bundle: true,
  minify: true,
  legalComments: 'none',
  platform: 'node',
  format: 'esm',
  target: 'esnext',
  loader: {'.ts': 'ts'},
  banner: {
    // https://github.com/evanw/esbuild/pull/2067#issuecomment-1072872075
    'js': 'import {createRequire} from "module";const require=createRequire(import.meta.url);',
  },
});