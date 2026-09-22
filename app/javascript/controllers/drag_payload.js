// Shared by the three drag-and-drop controllers, which all carry their payload
// as application/json and two of which share a page: the seeding panel sits
// beside the pool cards on an individual category, and the bracket sits beside
// them on a team category. A payload therefore has to say WHAT it is, or a row
// dropped on the wrong panel is PATCHed against the wrong endpoint with the
// wrong parameter name — which those endpoints read as "clear it", so a missed
// drop silently un-pools a participant or unseeds one.
//
// The url is also checked against this page's origin. A dataTransfer payload
// survives a drag from another document, so without that check a drag out of a
// hostile tab could name any url at all: move() would send this page's CSRF
// token there and render whatever came back into the admin page as a Turbo
// Stream. A payload that carries no url (the bracket swap posts to its own
// slot's url instead) is unaffected.
const TYPE = 'application/json';

function sameOrigin(url) {
  try {
    return new URL(url, window.location.origin).origin === window.location.origin;
  } catch {
    return false;
  }
}

// Whether a drag carries one of our payloads AT ALL. getData is unreadable
// during dragover — the browser protects the drag data until the drop — so a
// drop zone that wants to preventDefault a dragover has only the type list to
// go on. It is enough to keep a file or a text selection out, which a zone
// that preventDefaults everything would otherwise let the browser open in the
// tab when the drop turns out to carry nothing it recognises.
export function carriesDragPayload(event) {
  return Array.from(event.dataTransfer?.types || []).includes(TYPE);
}

export function writeDragPayload(dataTransfer, kind, data) {
  dataTransfer.setData(TYPE, JSON.stringify({ kind, ...data }));
}

export function readDragPayload(event, kind) {
  try {
    const payload = JSON.parse(event.dataTransfer.getData(TYPE));
    if (payload?.kind !== kind) return null;
    if (payload.url !== undefined && !sameOrigin(payload.url)) return null;
    return payload;
  } catch {
    return null;
  }
}
