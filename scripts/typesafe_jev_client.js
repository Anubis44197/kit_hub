/**
 * @file typesafe_jev_client.js
 * @description TypeSafe AI (Jev - System One) Karar ve Skorlama Motoru İstemcisi
 * Kit_Hub Ajanları için hızlı karar hakemliği (<500ms), kota korumalı önbellek ve fail-safe (güvenli yedek) motoru.
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// .env dosyasından anahtarı güvenle yükleme
function loadEnv() {
  const envPath = path.resolve(__dirname, '..', '.env');
  if (fs.existsSync(envPath)) {
    const content = fs.readFileSync(envPath, 'utf8');
    const lines = content.split('\n');
    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) continue;
      const eqIdx = trimmed.indexOf('=');
      if (eqIdx !== -1) {
        const key = trimmed.substring(0, eqIdx).trim();
        const val = trimmed.substring(eqIdx + 1).trim();
        if (!process.env[key]) {
          process.env[key] = val;
        }
      }
    }
  }
}

loadEnv();

const API_ENDPOINT = 'https://api.typesafe.ai/v1/systemone';
const DEFAULT_MODEL = process.env.TYPESAFE_MODEL || 'jev-latest';
const CACHE_FILE = path.resolve(__dirname, '..', 'runtime', '.cache', 'jev_cache.json');

// --- Önbellek Yönetimi (Kota Tasarrufu) ---
function getCacheKey(state, questions, model) {
  const payload = JSON.stringify({ state, questions, model });
  return crypto.createHash('sha256').update(payload).digest('hex');
}

function readCache(key) {
  try {
    if (fs.existsSync(CACHE_FILE)) {
      const data = JSON.parse(fs.readFileSync(CACHE_FILE, 'utf8'));
      return data[key] || null;
    }
  } catch {}
  return null;
}

function writeCache(key, value) {
  try {
    const dir = path.dirname(CACHE_FILE);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    let data = {};
    if (fs.existsSync(CACHE_FILE)) {
      try {
        data = JSON.parse(fs.readFileSync(CACHE_FILE, 'utf8'));
      } catch {}
    }
    data[key] = {
      cachedAt: new Date().toISOString(),
      response: value
    };
    fs.writeFileSync(CACHE_FILE, JSON.stringify(data, null, 2), 'utf8');
  } catch {}
}

/**
 * Hata tipinin kota/limit aşımı veya servis kesintisi olup olmadığını doğrular
 */
function isQuotaOrServiceIssue(error) {
  if (!error) return false;
  const msg = String(error.message || error).toLowerCase();
  return (
    msg.includes('429') ||
    msg.includes('402') ||
    msg.includes('quota') ||
    msg.includes('rate limit') ||
    msg.includes('insufficient_quota') ||
    msg.includes('credit') ||
    msg.includes('payment') ||
    msg.includes('enotfound') ||
    msg.includes('timeout')
  );
}

/**
 * TypeSafe AI Jev API'sine soru ve durum gönderir (Önbellek destekli).
 */
async function askJev(state, questions, options = {}) {
  const apiKey = process.env.TYPESAFE_API_KEY;
  if (!apiKey) {
    throw new Error('TYPESAFE_API_KEY ortam değişkeni veya .env dosyasında bulunamadı.');
  }

  if (!state || typeof state !== 'string' || state.trim().length === 0) {
    throw new Error('Geçersiz state parametresi: Değerlendirilecek bir metin girilmelidir.');
  }

  const model = options.model || DEFAULT_MODEL;
  const timeoutMs = options.timeoutMs || 10000;
  const cacheKey = getCacheKey(state, questions, model);

  // 1. Önbellek kontrolü (Kota harcanmaz)
  const cached = readCache(cacheKey);
  if (cached && !options.noCache) {
    return {
      ...cached.response,
      _fromCache: true
    };
  }

  // 2. Canlı API İsteği
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const res = await fetch(API_ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`
      },
      body: JSON.stringify({
        model,
        state,
        questions
      }),
      signal: controller.signal
    });

    if (!res.ok) {
      const errorText = await res.text();
      const err = new Error(`TypeSafe API Hatası [HTTP ${res.status}]: ${errorText}`);
      err.status = res.status;
      throw err;
    }

    const data = await res.json();
    writeCache(cacheKey, data);
    return data;
  } catch (err) {
    if (err.name === 'AbortError') {
      const timeoutErr = new Error(`TypeSafe API isteği zaman aşımına uğradı (${timeoutMs}ms).`);
      timeoutErr.isTimeout = true;
      throw timeoutErr;
    }
    throw err;
  } finally {
    clearTimeout(timer);
  }
}

// --- YEREL YEDEK KARAR MOTORU (FAIL-SAFE HEURISTIC ENGINE) ---
/**
 * Jev kotası bittiğinde veya erişilemediğinde devreye giren yerel kurallar
 */
function judgeLocalFallback(text, phase, reason) {
  const wordCount = (text.match(/\S+/g) || []).length;
  const charCount = text.length;

  const hasPlaceholder = /\[TODO\]|\[Buraya eklenecek\]|\.{4,}|\[TASLAK\]/i.test(text);
  const isTooShort = wordCount < 50;

  let verdict = 'PASS';
  let score = 1.6;
  const notes = [];

  if (hasPlaceholder) {
    verdict = 'REWRITE';
    score = 0.5;
    notes.push('Metinde [TODO] veya taslak yer tutucuları tespit edildi.');
  } else if (isTooShort) {
    verdict = 'REWRITE';
    score = 0.8;
    notes.push('Metin hedef uzunluğun çok altında (yetersiz hacim).');
  } else {
    notes.push('Yerel kural motoru biçim ve uzunluk kontrolünü onayladı.');
  }

  return {
    source: 'local_fallback',
    isFallback: true,
    warning: `TypeSafe Jev yedek modda çalıştı (${reason}). Sistem kesintisiz devam ediyor.`,
    verdict,
    score,
    confidence: 0.85,
    hasPlaceholder,
    wordCount,
    charCount,
    notes
  };
}

/**
 * Ajan Karar Hakemi: chief-editor-orchestrator veya verify_agent_run için karar üretir
 * @param {string} text - Ajanın ürettiği içerik veya bölüm
 * @param {string} phase - Aktif faz (create, polish, rewrite, export vb.)
 */
async function judgeAgentDecision(text, phase = 'create') {
  try {
    const questions = {
      decision: {
        type: 'choice',
        instructions: `Bu metin '${phase}' fazı standartlarına göre bir sonraki aşamaya geçmeli mi, yeniden yazılmalı mı, yoksa bloke mi edilmeli?`,
        criteria: {
          'PASS': 'Metin tutarlı, edebi kalite yeterli, sonraki aşamaya geçebilir.',
          'REWRITE': 'Metinde mantık kopukluğu, eksik anlatım veya belirgin aksaklıklar var, yeniden yazılmalı.',
          'BLOCKED': 'Ciddi kural ihlali, konu dışı içerik veya yapısal bozukluk var, faz durdurulmalı.'
        }
      },
      quality_score: {
        type: 'score',
        instructions: 'Metnin genel bütünlük ve edebi tatmin skoru nedir?',
        criteria: [
          'Yetersiz veya ham taslak seviyesinde',
          'Kabul edilebilir ve geliştirilmeye açık',
          'Üstün kalitede ve akıcı'
        ]
      },
      has_critical_issue: {
        type: 'noul',
        instructions: 'Metinde okuyucuyu rahatsız edecek kritik bir mantık hatası veya üslup kopukluğu var mı?'
      }
    };

    const response = await askJev(text, questions);
    const chosen = response.answers.decision.choice;
    const scoreVal = response.answers.quality_score.score;
    const issueRisk = response.answers.has_critical_issue.noul;

    let finalVerdict = chosen;
    // Güvenlik eşiği: Eğer kritik sorun riski > 0.70 ise veya skor çok düşükse kararı REWRITE yap
    if (issueRisk > 0.70 || scoreVal < 0.60) {
      finalVerdict = 'REWRITE';
    }

    return {
      source: 'jev',
      isFallback: false,
      fromCache: !!response._fromCache,
      model: response.model,
      verdict: finalVerdict,
      rawChoice: chosen,
      confidence: response.answers.decision.confidence,
      qualityScore: scoreVal,
      criticalIssueRisk: issueRisk,
      usage: response.usage
    };
  } catch (err) {
    // KOTA BİTERSE VEYA SERVİSE ERİŞİLEMEZSE: ASLA ÇÖKME, YEREL YEDEĞE GEÇ!
    const reasonMsg = isQuotaOrServiceIssue(err) ? 'Kota Sınırı / Bağlantı' : err.message;
    return judgeLocalFallback(text, phase, reasonMsg);
  }
}

/**
 * Ajan Yönlendirme (Chief Editor Router)
 */
async function routeAgent(text) {
  try {
    const questions = {
      target_agent: {
        type: 'choice',
        instructions: 'Bu metin içeriği ve ihtiyacı göz önüne alındığında hangi Kit_Hub editör ajanı çalışmalıdır?',
        criteria: {
          'tdk-polisher': 'İmla, noktalama, TDK uyumu, yazım yanlışları ve harf hataları düzeltme.',
          'line-editor': 'Cümle akıcılığı, ritim, kelime seçimi ve üslup cilalama.',
          'continuity-editor': 'Karakter tutarlılığı, zaman çizelgesi, mekan ve olay örgüsü devamlılığı.',
          'plot-hook-engineer': 'Bölüm sonu merak unsuru, kanca (hook), heyecan ve tempo yükseltme.',
          'character-sculptor': 'Karakter derinliği, motivasyon, diyalog doğallığı ve iç sesler.',
          'quality-verifier': 'Genel kalite denetimi ve son kontrol.'
        }
      },
      urgency: {
        type: 'noul',
        instructions: 'Metinde acil müdahale gerektiren ciddi bir tutarsızlık veya bozukluk var mı?'
      }
    };

    const response = await askJev(text, questions);
    return {
      source: 'jev',
      isFallback: false,
      fromCache: !!response._fromCache,
      model: response.model,
      selectedAgent: response.answers.target_agent.choice,
      confidence: response.answers.target_agent.confidence,
      probabilities: response.answers.target_agent.probabilities,
      urgentIssue: response.answers.urgency.noul > 0.6,
      urgencyScore: response.answers.urgency.noul,
      usage: response.usage
    };
  } catch (err) {
    return {
      source: 'local_fallback',
      isFallback: true,
      warning: `Jev ulaşılamadı (${err.message}). Varsayılan editör atandı.`,
      selectedAgent: 'quality-verifier',
      confidence: 0.8,
      urgentIssue: false
    };
  }
}

/**
 * Kalite Karnesi
 */
async function verifyQuality(text) {
  try {
    const questions = {
      pacing: {
        type: 'score',
        instructions: 'Sahnenin temposu ve akıcılığı nasıldır?',
        criteria: [
          'Aşırı yavaş, durağan ve sıkıcı',
          'Dengeli, sürükleyici ve tutarlı',
          'Aşırı hızlı, aceleye getirilmiş ve olaylar atlanmış'
        ]
      },
      grammar_health: {
        type: 'score',
        instructions: 'Türkçe dil bilgisi, imla ve cümle yapısı sağlığı nasıldır?',
        criteria: [
          'Çok sayıda hata ve bozuk cümle içeriyor',
          'Kabul edilebilir düzeyde, ufak pürüzler var',
          'Kusursuz, akıcı ve yüksek edebi kalite'
        ]
      },
      emotional_impact: {
        type: 'score',
        instructions: 'Okuyucuda bıraktığı duygusal derinlik ve gerilim nasıldır?',
        criteria: [
          'Düz ve duygusuz anlatım',
          'Orta derecede hissedilir duygu',
          'Güçlü ve etkileyici duygu aktarımı'
        ]
      },
      has_plot_hole: {
        type: 'noul',
        instructions: 'Metinde belirgin bir mantık hatası veya kopukluk var mı?'
      }
    };

    const response = await askJev(text, questions);
    return {
      source: 'jev',
      isFallback: false,
      fromCache: !!response._fromCache,
      model: response.model,
      pacingScore: response.answers.pacing.score,
      grammarHealthScore: response.answers.grammar_health.score,
      emotionalImpactScore: response.answers.emotional_impact.score,
      plotHoleRisk: response.answers.has_plot_hole.noul,
      rawAnswers: response.answers,
      usage: response.usage
    };
  } catch (err) {
    return {
      source: 'local_fallback',
      isFallback: true,
      warning: `Jev ulaşılamadı (${err.message}). Varsayılan puanlar üretildi.`,
      pacingScore: 1.0,
      grammarHealthScore: 1.5,
      emotionalImpactScore: 1.2,
      plotHoleRisk: 0.1
    };
  }
}

/**
 * Export Kapısı
 */
async function checkExportGate(text) {
  try {
    const questions = {
      is_ready_for_publication: {
        type: 'noul',
        instructions: 'Bu metin son okuması tamamlanmış ve yayına/baskıya hazır mı?'
      },
      contains_placeholder_text: {
        type: 'noul',
        instructions: 'Metinde [TODO], [Buraya eklenecek] veya taslak notu gibi unutulmuş yer tutucular var mı?'
      },
      structural_integrity: {
        type: 'score',
        instructions: 'Metnin giriş, gelişme, sonuç ve paragraf düzeni bütünlüğü nasıldır?',
        criteria: [
          'Yetersiz ve yarım kalmış',
          'Geliştirilmeye açık ama bütüncül',
          'Tamamlanmış ve profesyonel'
        ]
      }
    };

    const response = await askJev(text, questions);
    const readyProb = response.answers.is_ready_for_publication.noul;
    const placeholderProb = response.answers.contains_placeholder_text.noul;
    const structScore = response.answers.structural_integrity.score;

    const approved = readyProb >= 0.70 && placeholderProb < 0.20 && structScore >= 1.0;

    return {
      source: 'jev',
      isFallback: false,
      fromCache: !!response._fromCache,
      approved,
      readyProbability: readyProb,
      placeholderRisk: placeholderProb,
      structuralScore: structScore,
      model: response.model,
      usage: response.usage
    };
  } catch (err) {
    const hasPlaceholder = /\[TODO\]|\[Buraya eklenecek\]/i.test(text);
    return {
      source: 'local_fallback',
      isFallback: true,
      warning: `Jev ulaşılamadı (${err.message}). Yerel export kuralları uygulandı.`,
      approved: !hasPlaceholder && text.length > 500,
      readyProbability: 0.85,
      placeholderRisk: hasPlaceholder ? 0.99 : 0.05,
      structuralScore: 1.5
    };
  }
}

// CLI Kullanımı
if (require.main === module) {
  const args = process.argv.slice(2);
  const action = args[0] || '--test';

  (async () => {
    let targetText = args[1] || 'Ahmet soğuk kış gecesinde eski depoya yaklaştı. Kapının kırık kilidini fark edince tabancasını çekip emniyetini açtı. İçeriden gelen fısıltılar aniden kesildi.';

    // Eğer argüman bir dosya yolu ise dosya içeriğini oku
    if (args[1] && fs.existsSync(args[1])) {
      targetText = fs.readFileSync(args[1], 'utf8');
    }

    if (action === '--judge' || action === 'judge') {
      const phase = args[2] || 'create';
      const result = await judgeAgentDecision(targetText, phase);
      console.log(JSON.stringify(result, null, 2));
    } else if (action === '--route' || action === 'route') {
      const result = await routeAgent(targetText);
      console.log(JSON.stringify(result, null, 2));
    } else if (action === '--quality' || action === 'quality') {
      const result = await verifyQuality(targetText);
      console.log(JSON.stringify(result, null, 2));
    } else if (action === '--gate' || action === 'gate') {
      const result = await checkExportGate(targetText);
      console.log(JSON.stringify(result, null, 2));
    } else {
      console.log('[TypeSafe Jev Client - Fail-Safe Test]');
      const judgeRes = await judgeAgentDecision(targetText, 'create');
      console.log('Hakem Kararı:', judgeRes);
    }
  })();
}

module.exports = {
  askJev,
  judgeAgentDecision,
  routeAgent,
  verifyQuality,
  checkExportGate
};
