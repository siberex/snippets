import {join as pathJoin, basename, extname} from 'path';
import {promises as fs} from 'fs';
import glob from 'fast-glob';
import {Options} from 'fast-glob/out/settings';
import yaml from 'js-yaml';

/**
 * App Engine static route definition
 *
 * https://cloud.google.com/appengine/docs/standard/nodejs/serving-static-files#configuring_your_static_file_handlers
 * https://cloud.google.com/appengine/docs/standard/nodejs/config/appref#handlers_element
 *
 * Script will get all files from the `public` directory and will create proper `routes.yaml` definition for them.
 * Launch:
 *  $ tsc -p scripts && node -r source-map-support/register scripts/dist/make-static-handlers
 *
 * In the end will be added single dynamic route for NodeJS standard environment.
 *
 */

interface RouteType {
  url: string;
  secure?: string;
  redirect_http_response_code?: number;
}

interface StaticRouteType extends RouteType {
  static_files: string;
  upload: string;
  mime_type?: string;
  expiration?: string;
  http_headers?: {[key: string]: string};
}
interface DynamicRouteType extends RouteType {
  script?: 'auto';
}

const backendRoute: DynamicRouteType = {
  url: '/.*',
  secure: 'always',
  redirect_http_response_code: 301,
  script: 'auto',
};

const STATIC_DIR = pathJoin(process.cwd(), 'public');
const ROUTE_CONFIG = pathJoin(process.cwd(), 'routes.yaml');

type RouteFlagsType = {[key: string]: string | {[key: string]: string}};
const ROUTE_FLAGS: RouteFlagsType = {
  'site.webmanifest': {mime_type: 'application/json', expiration: '10m'},
  '*.ico': 'image/x-icon',
  'robots.txt': {expiration: '1s'},
  'sitemap.xml': {expiration: '1s'},
  '*.eot': 'application/vnd.ms-fontobject',
  '*.map': 'application/json',
  '*.ttf': 'font/ttf',
  '*.woff': 'font/woff',
  '*.woff2': 'font/woff2',
};

const IGNORE_FILES = ['**/.DS_Store', '**/LICENSE.txt', '**/config.json'];

const GLOB_OPTIONS: Options = {
  braceExpansion: false,
  caseSensitiveMatch: false,
  cwd: STATIC_DIR,
  extglob: false,
  followSymbolicLinks: false,
  ignore: IGNORE_FILES,
  onlyFiles: true,
};

const createRoute = (relPath: string, expand?: boolean): StaticRouteType => {
  let routeFlags = {};
  if (expand) {
    const extGlob = `*${extname(relPath)}`;
    if (typeof ROUTE_FLAGS[extGlob] === 'string') {
      routeFlags = {mime_type: ROUTE_FLAGS[extGlob]};
    } else {
      const fName = basename(relPath);
      routeFlags = ROUTE_FLAGS[fName];
    }
  }

  return {
    url: `/${relPath}`,
    static_files: `public/${relPath}`,
    upload: `public/${relPath}`,
    secure: 'always',
    redirect_http_response_code: 301,
    ...routeFlags,
  };
};

void (async () => {
  const routes: RouteType[] = [];
  console.info('📌 Creating static routes...');

  // const pattern = '**/('+Object.keys(ROUTE_FLAGS).join('|')+')';
  const pattern = Object.keys(ROUTE_FLAGS).map((k) => `**/${k}`);

  const filesKnown = await glob(pattern, GLOB_OPTIONS);

  for (const path of filesKnown) {
    routes.push(createRoute(path, true));
    console.info(path);
  }

  const filesAll = await glob('**/*.*', {
    ...GLOB_OPTIONS,
    ignore: IGNORE_FILES.concat(pattern),
  });

  for (const path of filesAll) {
    routes.push(createRoute(path));
    console.info(path);
  }

  // Dynamic (script) route goes last
  routes.push(backendRoute);

  const routesYaml = yaml.safeDump({handlers: routes}, {skipInvalid: true});
  await fs
    .writeFile(ROUTE_CONFIG, routesYaml)
    .then(() => {
      console.info(`✅ Success: ${ROUTE_CONFIG} saved.`);
    })
    .catch((err) => {
      console.error(err);
    });
})();
