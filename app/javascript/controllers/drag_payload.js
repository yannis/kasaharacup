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
