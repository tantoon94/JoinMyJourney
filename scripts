const admin = require('firebase-admin');
const fs = require('fs');

admin.initializeApp();

async function clearLikes() {
  const journeys = await admin.firestore().collection('journeys').get();
  for (const doc of journeys.docs) {
    // Set likes count to 0
    await doc.ref.update({ likes: 0 });

    // Delete all like docs in subcollection
    const likesCol = await doc.ref.collection('likes').get();
    for (const likeDoc of likesCol.docs) {
      await likeDoc.ref.delete();
    }
  }
  console.log('All likes cleared.');

  // Self-delete the script
  fs.unlinkSync(__filename);
  console.log('Script deleted itself.');
}

clearLikes(); 