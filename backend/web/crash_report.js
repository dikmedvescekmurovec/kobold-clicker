// The web build's crash report. A phone has no console, so this keeps the last lines the game printed and
// shows them over the game when something goes wrong: a badge for an error the game survives, the whole screen
// when the engine stops or the browser takes WebGL away, and on the next visit when the phone killed the tab.
// export_presets.cfg's head_include loads it before Godot's own script, so Godot's console calls go through the
// wrappers below; tools/web.py copies it beside index.html and writes the version over VERSION.
// ?crashtest=error|gl|oom|abort|killed fakes each case five seconds after load.
(function () {
'use strict';
const VERSION = '__VERSION__';
const KEY = 'kobold-crash';
const KEEP = 60;
const lines = [];  // [kind, text]: 'e' error, 'w' warning, 'm' this script's own, '' a print
let errors = 0, stopped = false, dirty = false, keepRecord = false, badge = null, open = null;

const HEADS = {
	script: ['Something went wrong', 'The game is still running, but part of it may not work.'],
	gl: ['Graphics lost after switching apps', 'The phone took the game\'s graphics away while it was in the background.'],
	oom: ['Game stopped: out of memory', 'The phone ran out of memory for the game.'],
	abort: ['Game stopped: engine error', 'The game hit an error it could not recover from.'],
	killed: ['Last session ended unexpectedly', 'The phone closed the game. These are the last lines it saved.'],
};

const clock = () => new Date().toTimeString().slice(0, 8);
const meta = () => [
	['m', 'Kobold Clicker ' + VERSION + ' · ' + new Date().toLocaleString('sv')],  // sv: 2026-10-30 21:14:07
	['m', navigator.userAgent]];

function text(arg) {
	if (arg instanceof Error) return arg.stack || String(arg);
	if (typeof arg === 'string') return arg;
	try { return JSON.stringify(arg); } catch (_) { return String(arg); }
}

function note(kind, args) {
	const all = Array.from(args, text).join(' ');
	// Godot sends its warnings to console.error as well.
	if (kind === 'e' && /^\s*(USER |SCRIPT )*WARNING/.test(all)) kind = 'w';
	for (const line of all.split('\n')) lines.push([kind, line]);
	lines.splice(0, Math.max(0, lines.length - KEEP));
	dirty = true;
	if (kind === 'e' && /^\s*(USER |SCRIPT )*ERROR/.test(all)) count();
}

function count() {
	errors++;
	save();
	if (!stopped) whenReady(showBadge);
}

for (const [name, kind] of [['log', ''], ['warn', 'w'], ['error', 'e']]) {
	const real = console[name];
	console[name] = function () {
		try { note(kind, arguments); } catch (_) { /* never let the report break a print */ }
		return real.apply(console, arguments);
	};
}

function save() {
	dirty = false;
	try {
		localStorage.setItem(KEY, JSON.stringify({ at: clock(), visible: !document.hidden, stopped: stopped,
			lines: lines }));
	} catch (_) { /* a private window: nothing is kept for the next visit */ }
}
setInterval(() => { if (dirty) save(); }, 5000);
document.addEventListener('visibilitychange', () => {
	if (keepRecord) return;  // the crash test's own leaving would otherwise save it as a tab in the background
	note('m', ['Page ' + document.visibilityState + ' ' + clock()]);
	save();
});
// A tab closed or reloaded on purpose leaves nothing behind; one the phone killed never gets here.
window.addEventListener('pagehide', () => {
	if (keepRecord) return;
	try { localStorage.removeItem(KEY); } catch (_) { /* nothing to clear */ }
});

// Emscripten's abort() throws a WebAssembly.RuntimeError "Aborted(...)"; after it the engine never runs again.
function crashed(err) {
	if (!(err instanceof WebAssembly.RuntimeError || /Aborted\(/.test(String(err && err.message || err)))) {
		count();
		return;
	}
	// "memory access out of bounds" is a bug, not the phone running out of memory.
	stop(/OOM|enlarge memory|allocate memory/i.test(String(err && err.message || err)) ? 'oom' : 'abort');
}
function stop(cause) {
	if (stopped) return;
	stopped = true;
	save();
	whenReady(() => {
		if (badge) badge.remove();
		if (open) open.remove();
		show(cause, lines, { full: true, reload: true });
	});
}
window.addEventListener('error', ev => {
	note('e', [ev.error || ev.message]);
	crashed(ev.error || ev.message);
});
window.addEventListener('unhandledrejection', ev => {
	note('e', [ev.reason]);
	crashed(ev.reason);
});
// Godot answers a lost context with a bare alert() and never restores it; this runs first and replaces that.
window.addEventListener('webglcontextlost', ev => {
	ev.preventDefault();
	ev.stopImmediatePropagation();
	note('w', ['WebGL context lost ' + clock()]);
	stop('gl');
}, true);

function whenReady(fn) {
	if (document.body) fn();
	else document.addEventListener('DOMContentLoaded', fn, { once: true });
}

const CSS = `
.kc-badge { position: fixed; z-index: 2147483000; top: calc(14px + env(safe-area-inset-top, 0px));
	right: calc(12px + env(safe-area-inset-right, 0px)); min-height: 44px; padding: 0 14px; border-radius: 22px;
	display: flex; align-items: center; gap: 8px; cursor: pointer; background: #891e2b; color: #f9e6cf;
	border: 2px solid #1c121c; box-shadow: 0 2px 0 #1c121c; font: 600 14px system-ui, -apple-system, sans-serif; }
.kc-badge i { width: 8px; height: 8px; border-radius: 50%; background: #f5555d; }
.kc-over { position: fixed; z-index: 2147483001; inset: 0; display: flex; flex-direction: column;
	justify-content: flex-end; background: rgba(19, 19, 19, .55); padding: env(safe-area-inset-top, 0px)
	env(safe-area-inset-right, 0px) env(safe-area-inset-bottom, 0px) env(safe-area-inset-left, 0px);
	font: 14px system-ui, -apple-system, sans-serif; -webkit-user-select: none; user-select: none; }
.kc-over.kc-full { background: rgba(19, 19, 19, .88); justify-content: center; }
.kc-sheet { position: relative; margin: 10px auto; width: calc(100% - 20px); max-width: 480px;
	max-height: calc(100% - 20px); display: flex; flex-direction: column; min-height: 0; box-sizing: border-box;
	background: #f6ca9f; color: #391f21; border: 2px solid #1c121c; border-radius: 10px; box-shadow: 0 3px 0 #1c121c; }
.kc-head { background: #891e2b; color: #f9e6cf; padding: 12px 54px 12px 14px; border-radius: 7px 7px 0 0;
	display: grid; gap: 2px; }
.kc-head strong { font-size: 17px; line-height: 1.25; }
.kc-head small { font-size: 13px; opacity: .85; }
.kc-close { position: absolute; top: 6px; right: 6px; width: 44px; height: 44px; border: 0; background: none;
	color: #f9e6cf; font-size: 22px; cursor: pointer; }
.kc-lines { margin: 12px; padding: 10px; background: #1a1932; color: #f9e6cf; border-radius: 6px;
	font: 12px/1.45 ui-monospace, Menlo, Consolas, monospace; white-space: pre-wrap; overflow-wrap: anywhere;
	overflow-y: auto; min-height: 0; flex: 1 1 auto; max-height: 50vh; touch-action: pan-y;
	-webkit-overflow-scrolling: touch; -webkit-user-select: text; user-select: text; }
.kc-lines .e { color: #f5555d; } .kc-lines .w { color: #ffc825; } .kc-lines .m { color: #9d9dc8; }
.kc-buttons { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; padding: 0 12px 12px; }
.kc-buttons button { min-height: 44px; border-radius: 6px; border: 2px solid #1c121c; cursor: pointer;
	background: #8a4836; color: #f9e6cf; font: 600 15px system-ui, -apple-system, sans-serif;
	box-shadow: 0 2px 0 #1c121c; }
.kc-buttons button.kc-main { background: #1e6f50; }
.kc-buttons button:active { transform: translateY(2px); box-shadow: none; }
.kc-toast { position: absolute; left: 50%; bottom: 74px; transform: translateX(-50%); background: #1c121c;
	color: #f9e6cf; padding: 8px 14px; border-radius: 6px; font-size: 13px; white-space: nowrap;
	pointer-events: none; transition: opacity .2s; }
`;
let styled = false;
function style() {
	if (styled) return;
	styled = true;
	const el = document.createElement('style');
	el.textContent = CSS;
	document.head.appendChild(el);
}

function showBadge() {
	style();
	if (open) return;
	if (!badge) {
		badge = document.createElement('button');
		badge.className = 'kc-badge';
		badge.onclick = () => { badge.remove(); badge = null; show('script', lines, { full: false, reload: false }); };
		document.body.appendChild(badge);
	}
	badge.innerHTML = '<i></i>' + errors + (errors === 1 ? ' error' : ' errors');
}

function show(cause, shown, opts) {
	style();
	const all = meta().concat(shown);
	const plain = all.map(l => l[1]).join('\n');
	const over = document.createElement('div');
	over.className = 'kc-over' + (opts.full ? ' kc-full' : '');
	const sheet = document.createElement('div');
	sheet.className = 'kc-sheet';
	sheet.setAttribute('role', 'dialog');
	const head = document.createElement('div');
	head.className = 'kc-head';
	head.innerHTML = '<strong></strong><small></small>';
	head.firstChild.textContent = HEADS[cause][0];
	head.lastChild.textContent = HEADS[cause][1];
	const box = document.createElement('div');
	box.className = 'kc-lines';
	for (const [kind, line] of all) {
		const span = document.createElement('span');
		span.className = kind;
		span.textContent = line + '\n';
		box.appendChild(span);
	}
	const buttons = document.createElement('div');
	buttons.className = 'kc-buttons';
	const button = (label, cls, fn) => {
		const b = document.createElement('button');
		b.textContent = label;
		if (cls) b.className = cls;
		b.onclick = fn;
		buttons.appendChild(b);
	};
	const toast = msg => {
		let t = sheet.querySelector('.kc-toast');
		if (!t) { t = document.createElement('div'); t.className = 'kc-toast'; sheet.appendChild(t); }
		t.textContent = msg;
		t.style.opacity = 1;
		clearTimeout(t.timer);
		t.timer = setTimeout(() => { t.style.opacity = 0; }, 1600);
	};
	const copy = () => (navigator.clipboard ? navigator.clipboard.writeText(plain) : Promise.reject())
		.then(() => toast('Copied'), () => {
			const range = document.createRange();
			range.selectNodeContents(box);
			getSelection().removeAllRanges();
			getSelection().addRange(range);
			toast('Selected: copy it by hand');
		});
	const close = () => {
		over.remove();
		open = null;
		if (!opts.full && errors && !stopped) showBadge();
	};
	button('Share', 'kc-main', () => {
		if (!navigator.share) return copy();
		navigator.share({ title: 'Kobold Clicker error', text: plain }).catch(err => {
			if (err && err.name !== 'AbortError') copy();
		});
	});
	button('Copy', '', copy);
	if (opts.reload) button('Reload', '', () => location.reload());
	else button('Continue', '', close);
	sheet.append(head, box, buttons);
	if (!opts.reload) {
		const x = document.createElement('button');
		x.className = 'kc-close';
		x.setAttribute('aria-label', 'Close');
		x.textContent = '✕';
		x.onclick = close;
		sheet.appendChild(x);
	}
	over.appendChild(sheet);
	document.body.appendChild(over);
	open = over;
}

// The last visit's record: still there means it never reached pagehide, and visible means the phone did not
// just close a tab in the background, which is how a player leaves a game on a phone.
let last = null;
try { last = JSON.parse(localStorage.getItem(KEY) || 'null'); } catch (_) { /* no record */ }
save();
if (last && last.visible && !last.stopped && last.lines && last.lines.length) {
	const shown = [['m', 'Last heard from ' + last.at]].concat(last.lines);
	whenReady(() => show('killed', shown, { full: true, reload: false }));
}

const test = new URLSearchParams(location.search).get('crashtest');
if (test) window.addEventListener('load', () => setTimeout(() => {
	if (test === 'error') console.error('SCRIPT ERROR: crash test\n   at: _crash_test (crash_report.js)');
	if (test === 'gl') {
		const gl = document.getElementById('canvas').getContext('webgl2');
		if (gl) gl.getExtension('WEBGL_lose_context').loseContext();
	}
	if (test === 'oom') throw new WebAssembly.RuntimeError('Aborted(OOM)');
	if (test === 'abort') throw new WebAssembly.RuntimeError('Aborted(memory access out of bounds)');
	if (test === 'killed') {
		note('m', ['crash test: the phone kills the tab']);
		keepRecord = true;
		save();
		location.replace(location.pathname);
	}
}, 5000));
})();
