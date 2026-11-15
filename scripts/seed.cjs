const functionsRequire = require('node:module').createRequire(require('node:path').join(__dirname,'../functions/package.json'));
const {initializeApp} = functionsRequire('firebase-admin/app');
const {getFirestore} = functionsRequire('firebase-admin/firestore');
if (!process.env.FIRESTORE_EMULATOR_HOST) throw Error('Seed only the local emulator.');
initializeApp({projectId:'demo-cloud-quest'});
getFirestore().doc('challenges/today').set({
  title:'Identity is not permission',
  prompt:'Explain the difference between authentication and authorization. Give one example of a signed-in learner who should still be denied access to another learner’s progress.'
}).then(() => { console.log('Seeded challenges/today'); process.exit(0); });
