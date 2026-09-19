const fs = require("fs");
const path = require("path");
const esbuild = require("esbuild");

const root = path.resolve(__dirname, "..");

const targets = {
  "studio-editor": {
    entry: "src/studio-editor.js",
    outfile: "assets/studio-editor.js",
    options: {}
  },
  "page-flow": {
    entry: "src/page-flow.js",
    outfile: "assets/page-flow.js",
    options: { globalName: "KitHubPageFlow" }
  },
  professional: {
    entry: "src/studio-professional.js",
    outfile: "assets/studio-professional.js",
    options: { globalName: "KitHubProfessionalBundle" }
  },
  "studio-wizard": {
    entry: "src/studio-wizard.js",
    outfile: "assets/studio-wizard.js",
    options: { globalName: "KitHubWizardBundle" }
  }
};

const bareImportResolver = {
  name: "node-require-resolver",
  setup(build) {
    build.onResolve({ filter: /^\./ }, args => {
      const basePath = path.resolve(args.resolveDir || root, args.path);
      const candidates = [
        basePath,
        `${basePath}.js`,
        `${basePath}.mjs`,
        `${basePath}.cjs`,
        `${basePath}.css`,
        path.join(basePath, "index.js"),
        path.join(basePath, "index.mjs"),
        path.join(basePath, "index.cjs")
      ];
      for (const candidate of candidates) {
        if (fs.existsSync(candidate) && fs.statSync(candidate).isFile()) {
          return { path: candidate };
        }
      }
      return null;
    });

    build.onResolve({ filter: /^[^./]|^\.[^./]|^\.\.[^/]/ }, args => {
      try {
        return {
          path: require.resolve(args.path, {
            paths: [args.resolveDir || root, root]
          })
        };
      } catch {
        return null;
      }
    });
  }
};

async function buildTarget(name) {
  const target = targets[name];
  if (!target) {
    throw new Error(`Unknown build target: ${name}`);
  }

  const entryPath = path.join(root, target.entry);
  const source = fs.readFileSync(entryPath, "utf8");
  const buildOptions = {
    stdin: {
      contents: source,
      resolveDir: path.dirname(entryPath),
      sourcefile: target.entry
    },
    bundle: true,
    format: "iife",
    target: ["chrome109", "edge109"],
    minify: true,
    plugins: [bareImportResolver],
    ...target.options
  };

  if (target.outfile) {
    buildOptions.outfile = path.join(root, target.outfile);
  }
  if (target.outdir) {
    buildOptions.outdir = path.join(root, target.outdir);
  }

  await esbuild.build(buildOptions);
  console.log(`[build-assets] ${name} ok`);
}

async function main() {
  const requested = process.argv.slice(2);
  const names = requested.length ? requested : Object.keys(targets);
  for (const name of names) {
    await buildTarget(name);
  }
}

main().catch(error => {
  console.error(error);
  process.exit(1);
});
