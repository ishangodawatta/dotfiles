"""Rebuild a Fusion script automatically whenever its file changes on disk.

Fusion ships no headless mode, so a build script can only run inside the
running application. This add-in removes the clicking: it watches every script
registered under the API Scripts folder, following symlinks out to wherever
the source actually lives, and re-runs one as soon as it is saved.

The watched script is expected to be idempotent, because it will be run
repeatedly into the same document. Clear the timeline at the top of run().

Install: symlink this directory into
    ~/Library/Application Support/Autodesk/Autodesk Fusion 360/API/AddIns/
then enable it in Scripts and Add-Ins, with Run on Startup ticked.
"""

import os
import threading
import traceback

import adsk.core

SCRIPTS_DIR = os.path.expanduser(
    "~/Library/Application Support/Autodesk/Autodesk Fusion 360/"
    "API/Scripts")

POLL_SECONDS = 1.0
EVENT_ID = "FusionScriptWatchRebuild"

_app = None
_ui = None
_event = None
_handlers = []          # Fusion garbage-collects handlers that are not held
_stop = threading.Event()
_thread = None
_pending = []


def _watched():
    """Every registered script, as {resolved path: mtime}.

    Resolved, because the scripts here are symlinks into project repositories
    and it is the target's mtime that moves when the source is edited.
    """
    found = {}
    try:
        for entry in os.listdir(SCRIPTS_DIR):
            script = os.path.join(SCRIPTS_DIR, entry, entry + ".py")
            if not os.path.isfile(script):
                continue
            target = os.path.realpath(script)
            try:
                found[target] = os.path.getmtime(target)
            except OSError:
                pass
    except OSError:
        pass
    return found


def _watch_loop():
    """Poll off the main thread; fire a custom event so the rebuild runs on it.

    The Fusion API is not thread safe, so nothing here touches a document. The
    only job is to notice a changed file and hand the path to the main thread.
    """
    seen = _watched()
    while not _stop.wait(POLL_SECONDS):
        current = _watched()
        for path, mtime in current.items():
            if seen.get(path) != mtime and path in seen:
                _pending.append(path)
                try:
                    _app.fireCustomEvent(EVENT_ID, path)
                except Exception:
                    pass
        seen = current


class _RebuildHandler(adsk.core.CustomEventHandler):
    def notify(self, args):
        path = None
        try:
            path = _pending.pop(0) if _pending else args.additionalInfo
            source = open(path).read()
            namespace = {"__name__": "__main__", "__file__": path}
            exec(compile(source, path, "exec"), namespace)
            entry = namespace.get("run")
            if callable(entry):
                entry(None)
            else:
                _ui.messageBox(f"{os.path.basename(path)} has no run()")
        except Exception:
            # A dialog left open blocks every later run, so the traceback goes
            # to a file beside the script and only a short message is shown.
            tb = traceback.format_exc()
            try:
                log = os.path.join(os.path.dirname(path or SCRIPTS_DIR),
                                   "watch-error.log")
                with open(log, "w") as handle:
                    handle.write(tb)
            except Exception:
                pass
            if _ui:
                _ui.messageBox("Rebuild failed, see watch-error.log:\n\n" + tb)


def run(context):
    global _app, _ui, _event, _thread
    try:
        _app = adsk.core.Application.get()
        _ui = _app.userInterface

        try:
            _app.unregisterCustomEvent(EVENT_ID)
        except Exception:
            pass
        _event = _app.registerCustomEvent(EVENT_ID)
        handler = _RebuildHandler()
        _event.add(handler)
        _handlers.append(handler)

        _stop.clear()
        _thread = threading.Thread(target=_watch_loop, daemon=True)
        _thread.start()
    except Exception:
        if _ui:
            _ui.messageBox("Watch failed to start:\n\n" + traceback.format_exc())


def stop(context):
    try:
        _stop.set()
        if _thread:
            _thread.join(timeout=2 * POLL_SECONDS)
        if _app:
            _app.unregisterCustomEvent(EVENT_ID)
        _handlers.clear()
    except Exception:
        pass
