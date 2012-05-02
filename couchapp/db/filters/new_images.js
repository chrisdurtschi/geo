function(doc, req) {
  if (!doc._deleted && doc._attachments) {
    if (doc.type === 'tag' &&
      (!doc._attachments['icon_ldpi.jpg'] ||
       !doc._attachments['icon_mdpi.jpg'] ||
       !doc._attachments['icon_hdpi.jpg'] ||
       !doc._attachments['icon_xdpi.jpg'] ||
       !doc._attachments['transparent_ldpi.png'] ||
       !doc._attachments['transparent_mdpi.png'] ||
       !doc._attachments['transparent_hdpi.png'] ||
       !doc._attachments['transparent_xdpi.png'] ||
       !doc._attachments['normalized.jpg'])) {
      return true;
    } else if (doc.type === 'capture' && !doc._attachments['normalized.jpg']) {
      return true;
    }
  }

  return false;
}
