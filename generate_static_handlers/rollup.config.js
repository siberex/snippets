import commonjs from '@rollup/plugin-commonjs';
import nodeResolve from '@rollup/plugin-node-resolve';
import {terser} from 'rollup-plugin-terser';
import typescript from '@rollup/plugin-typescript';

export default {
  input: 'make-static-handlers.ts',
  output: {
    file: 'dist/main.js',
    format: 'es',
    sourcemap: false,
  },
  plugins: [
    typescript(),
    commonjs({
      ignoreGlobal: true,
      sourceMap: false,
    }),
    nodeResolve({
      preferBuiltins: true
    }),
    terser({
      ecma: 2020,
      compress: {
        arguments: true,
        passes: 3,
        toplevel: true,
      },
      format: {
        comments: false,
      }
    }),
  ]
};