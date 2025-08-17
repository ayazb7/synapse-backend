-- Enhanced explanations for existing questions
-- This script updates the questions with L1 key points, detailed explanations, and ELI5 explanations

-- Q1: ECG for suspected ACS
UPDATE questions 
SET 
  explanation_l1_points = ARRAY[
    'ECG is the most critical immediate investigation for suspected STEMI',
    'Time is muscle - rapid diagnosis and intervention saves cardiac tissue',
    'Cardiology review needed for potential primary PCI',
    'Other options delay definitive diagnosis and treatment'
  ],
  detailed_context = 'This presentation is highly suggestive of acute STEMI. The combination of crushing chest pain with radiation, diaphoresis, and hemodynamic compromise requires immediate evaluation. According to NICE guidelines, ECG should be performed within 10 minutes of presentation for suspected ACS.',
  detailed_pathophysiology = 'Acute coronary occlusion leads to myocardial ischemia and necrosis. Early reperfusion therapy (primary PCI or thrombolysis) within the first 12 hours significantly improves outcomes by restoring coronary flow and limiting infarct size.',
  explanation_eli5 = 'Think of the heart like a house with electrical wiring (the ECG shows this). When someone has a heart attack, it''s like a power outage in part of the house. We need to check the electrical system (ECG) immediately to see which part is affected and call the repair team (cardiology) right away!'
WHERE stem LIKE '%58-year-old man presents with 30 minutes of central crushing chest pain%'
  AND type = 'MCQ';

-- Q2: Antiplatelet loading in NSTEMI
UPDATE questions 
SET 
  explanation_l1_points = ARRAY[
    'Aspirin 300mg is the standard loading dose for suspected ACS',
    'Should be given early unless contraindicated',
    'Chewed or dispersed for faster absorption',
    'Reduces mortality and further thrombotic events'
  ],
  detailed_context = 'In suspected NSTEMI, immediate antiplatelet therapy is crucial to prevent further thrombotic events. The loading dose provides rapid platelet inhibition while awaiting further cardiac assessment and potential dual antiplatelet therapy.',
  detailed_pathophysiology = 'Aspirin irreversibly inhibits cyclooxygenase-1, preventing thromboxane A2 synthesis and reducing platelet aggregation. The 300mg loading dose ensures rapid and complete platelet inhibition, which is maintained for the platelet lifespan (7-10 days).',
  explanation_eli5 = 'When blood vessels get blocked by sticky clots, aspirin makes the blood less sticky so new clots can''t form. We give a big dose first (like a jump-start) to work quickly, then smaller doses to keep it working.'
WHERE stem LIKE '%67-year-old with suspected NSTEMI%'
  AND type = 'MCQ';

-- Q3: Troponin biomarker
UPDATE questions 
SET 
  explanation_l1_points = ARRAY[
    'Troponin I or T is the gold standard biomarker for myocardial injury',
    'Highly specific and sensitive for cardiac muscle damage',
    'Serial measurements show rise and fall pattern in MI',
    'Interpret in clinical context with ECG and symptoms'
  ],
  detailed_context = 'High-sensitivity troponin assays can detect very small amounts of cardiac muscle damage. The timing of sampling is crucial - troponin typically rises 3-6 hours after symptom onset and peaks at 12-24 hours.',
  detailed_pathophysiology = 'Troponins are regulatory proteins found in cardiac and skeletal muscle. During myocardial necrosis, troponin is released into the bloodstream. The rise and fall pattern helps distinguish acute MI from chronic elevation due to other causes.',
  explanation_eli5 = 'Troponin is like a special alarm that only goes off when heart muscle gets damaged. It''s very sensitive - even tiny amounts of damage will set it off, which helps doctors know if you''ve had a heart attack.'
WHERE stem LIKE '%most specific blood biomarker for myocardial injury%'
  AND type = 'SAQ';

-- Q4: Inferior STEMI culprit vessel
UPDATE questions 
SET 
  explanation_l1_points = ARRAY[
    'Inferior STEMI (leads II, III, aVF) usually involves the RCA',
    'RCA supplies the inferior wall of the left ventricle',
    'Consider right ventricular involvement with inferior MI',
    'LCx can cause inferior MI in left-dominant systems'
  ],
  detailed_context = 'The anatomical correlation between ECG changes and coronary anatomy is crucial for understanding the extent of myocardial damage and planning intervention. Inferior STEMI has specific complications including heart block and right ventricular involvement.',
  detailed_pathophysiology = 'In most patients (85%), the RCA is the dominant vessel supplying the inferior wall, posterior descending artery, and AV node. Occlusion causes inferior wall ischemia with characteristic ECG changes in leads II, III, and aVF.',
  explanation_eli5 = 'The heart has three main "highways" for blood (coronary arteries). When we see certain warning signs on the heart monitor (ECG), we can tell which highway is blocked. For the bottom part of the heart, it''s usually the right highway (RCA) that''s blocked.'
WHERE stem LIKE '%ECG shows ST elevation in leads II, III, and aVF%'
  AND type = 'MCQ';

-- Q5: Aspirin loading dose
UPDATE questions 
SET 
  explanation_l1_points = ARRAY[
    '300mg is the standard loading dose for aspirin in ACS',
    'Should be chewed or dispersed for rapid absorption',
    'Give early unless contraindicated (bleeding, allergy)',
    'Followed by 75mg daily maintenance dose'
  ],
  detailed_context = 'The loading dose of aspirin provides immediate antiplatelet effect, which is crucial in the acute phase of ACS. The chewable or dispersible formulation ensures rapid absorption and onset of action.',
  detailed_pathophysiology = 'The 300mg loading dose provides complete and irreversible inhibition of platelet cyclooxygenase-1 within 30 minutes when chewed. This prevents thromboxane A2 synthesis and reduces platelet aggregation at the site of plaque rupture.',
  explanation_eli5 = 'When someone has a heart attack, we need to stop more blood clots from forming quickly. We give a big dose of aspirin (300mg) that works like putting oil on sticky gears - it makes the blood less sticky right away.'
WHERE stem LIKE '%recommended initial loading dose of aspirin%'
  AND type = 'SAQ';
