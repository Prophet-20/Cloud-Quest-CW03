const {initializeApp} = require('firebase-admin/app');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
initializeApp();
const db = getFirestore();
exports.completeToday = onCall(async request => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  if (request.data?.challengeId !== 'today') {
    throw new HttpsError('invalid-argument', 'Unknown challenge.');
  }
  const progressRef = db.doc(`users/${request.auth.uid}/progress/today`);
  return db.runTransaction(async tx => {
    const challenge = await tx.get(db.doc('challenges/today'));
    if (!challenge.exists) throw new HttpsError('not-found', 'Challenge unavailable.');
    const progress = await tx.get(progressRef);
    if (progress.exists) {
      const {completed, points, badgeId} = progress.data();
      return {completed, points, badgeId, alreadyCompleted:true};
    }
    const reward = {completed:true, points:10, badgeId:'first-quest'};
    tx.set(progressRef, {...reward, completedAt:FieldValue.serverTimestamp()});
    return {...reward, alreadyCompleted:false};
  });
});
exports.askQuestCoach = require('./questCoach').askQuestCoach;
