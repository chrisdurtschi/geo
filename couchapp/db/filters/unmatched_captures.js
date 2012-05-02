function(doc, req) {
  if (!doc._deleted && doc.type === 'capture' && doc._attachments &&
      doc._attachments['normalized.jpg'] && !doc.match) {
    return true;
  }

  return false;
}
