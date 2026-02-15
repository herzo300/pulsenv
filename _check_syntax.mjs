import { readFileSync } from 'fs';
const code = readFileSync('cloudflare-worker/worker.js', 'utf-8');

// Find MAP_HTML properly - it's a template literal
const marker = 'const MAP_HTML = `';
const start = code.indexOf(marker);
console.log('MAP_HTML starts at char:', start);

// Now we need to find the matching closing backtick
// Template literal: backtick closes at unescaped backtick
let pos = start + marker.length;
let depth = 0;
while (pos < code.length) {
  if (code[pos] === '\\') {
    pos += 2; // skip escaped char
    continue;
  }
  if (code[pos] === '`') {
    // Found closing backtick
    console.log('Closing backtick at char:', pos);
    console.log('MAP_HTML total length:', pos - start - marker.length);
    console.log('Last 300 chars before close:', JSON.stringify(code.substring(pos-300, pos)));
    console.log('After close:', JSON.stringify(code.substring(pos, pos+100)));
    break;
  }
  pos++;
}
