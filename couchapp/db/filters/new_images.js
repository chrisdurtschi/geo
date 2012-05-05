function(doc, req) {
  if (!doc._deleted && doc._attachments) {
    if (doc.type === 'tag' &&
      (!doc._attachments['icon_ldpi.jpg'] ||
       !doc._attachments['icon_mdpi.jpg'] ||
       !doc._attachments['icon_hdpi.jpg'] ||
       !doc._attachments['icon_xdpi.jpg'] ||
       !doc._attachments['normalized.jpg'])) {
      return true;
    } else if (doc.type === 'capture' && !doc._attachments['normalized.jpg']) {
      return true;
    }
  }

  return false;
}
