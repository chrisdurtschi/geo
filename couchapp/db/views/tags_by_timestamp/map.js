function(doc) {
  if (doc.type === 'tag') {
    emit(doc.timestamp, 1);
  }
}
