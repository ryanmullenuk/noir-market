import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse } from 'acorn';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const output = path.join(root, 'ios/Generated/Web');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');

function replaceOnce(source, before, after) {
  if (source.split(before).length !== 2) throw new Error('iOS packaging source changed: ' + before);
  return source.replace(before, after);
}

export function nativeGameSource(source) {
  source = replaceOnce(source,
    "    if(typeof state.allCitiesUnlocked!=='boolean')state.allCitiesUnlocked=false;",
    "    state.allCitiesUnlocked=window.__NOIR_IOS_ENTITLED===true;\n    if(!state.allCitiesUnlocked)state.accessMode='free';");
  const start = source.indexOf('  function requestUnlockV95(callback){');
  const end = source.indexOf('  function startPickerHtmlV95(full){', start);
  if (start < 0 || end < start) throw new Error('iOS purchase function boundaries changed');
  source = source.slice(0, start) + `  function requestUnlockV95(callback){
    pendingUnlockCallbackV95=typeof callback==='function'?callback:null;
    try{
      window.webkit.messageHandlers.noirPurchase.postMessage({productId:PRODUCT_ID});
    }catch(e){
      pendingUnlockCallbackV95=null;
      modal('Purchase unavailable','<p>The App Store connection is unavailable. Close this message to continue with Free Play.</p>');
    }
  }

` + source.slice(end);
  source = replaceOnce(source, "if('serviceWorker' in navigator){", "if(false){ /* Native build uses bundled resources, not a service worker. */");
  if (/unlockWebPreviewV95|UNLOCK WEB PREVIEW/.test(source)) throw new Error('Web preview unlock leaked into iOS');
  parse(source, { ecmaVersion: 'latest' });
  return source;
}

export function nativeHTML(source) {
  return source
    .replace(/^.*<link rel="(?:manifest|apple-touch-icon)".*\n/gm, '')
    .replace(/(styles\.css|game\.js)\?v=[\d.]+/g, '$1');
}

export function prepareIOS() {
  fs.mkdirSync(path.join(output, 'assets'), { recursive: true });
  fs.writeFileSync(path.join(output, 'game.js'), nativeGameSource(read('game.js')));
  fs.writeFileSync(path.join(output, 'index.html'), nativeHTML(read('ios/game-shell.html.template')));
  for (const name of ['styles.css', 'assets/redhead-games-logo.png', 'assets/game-music.mp3']) {
    fs.copyFileSync(path.join(root, name), path.join(output, name));
  }
  console.log('Prepared offline iOS resources at ' + output);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) prepareIOS();
