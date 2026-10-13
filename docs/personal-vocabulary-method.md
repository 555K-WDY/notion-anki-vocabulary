# Personal Vocabulary Library: Method and Rationale

## Why build a personal vocabulary library?

A general word list records items without the learner's reason for noticing them. This library keeps a word attached to the sentence, topic, Chinese interpretation, question, story, or personal association that made it worth recording. That context helps the learner distinguish senses and choose an expression in a real speaking or writing moment.

The library has three jobs:

1. Capture vocabulary from reading, listening, writing, speaking, lessons, and daily life without interrupting the activity that produced it.
2. Turn each record into usable knowledge: form, meaning, pronunciation, collocation, register, and a natural example.
3. Provide repeated opportunities to retrieve and use the item, while preserving the original record so later corrections remain traceable.

This is a personal learning design informed by research, not a claim that one card format works best for every learner or every word.

## The learning model

The workflow connects five operations.

### 1. Capture authentic input

Record the target and whatever context is available: source sentence, topic, Chinese note, example, story, image, or uncertain fragment. Keep the original wording. If spelling or grammar is imperfect, record a separate interpretation and correction rather than silently replacing the evidence.

### 2. Encode meaning and use

A vocabulary item is more than a translation. For a content word, retain the relevant sense and connect it to a clear concept or image. For production, learn a useful lexical chunk with the word and its grammatical pattern. Keep chunks natural and relevant; do not assemble unrelated words merely to make a longer target.

For a function word, the useful response may be an attention or discourse move rather than a concrete object. Use a short English trigger label, then explain the function through a typical context and sentence.

### 3. Retrieve in a meaningful situation

The front of an ordinary card presents the target and pronunciation, one or two scenario-linked chunks, a concrete English situation, and a separate question. The answer stays hidden. The learner first tries to produce a natural response from the situation; the back then shows a likely spoken expression and examples.

This design makes the retrieval cue resemble a future use situation. It encourages retrieval of a whole usable phrase instead of recognition of an isolated translation. Retrieval practice reliably benefits later retention, while transfer to new contexts depends on cue and task similarity and is not automatic. Scenarios therefore need variety and should be paired with real speaking and writing practice.

### 4. Add distinct memory cues

Meaning-specific images support the concept represented by the word or chunk. Separate audio supports hearing and producing the target, chunks, answers, and examples. These cues are kept separate by role: the concept image is not a picture of the speaking scenario, and an audio control is not duplicated on the same card face.

Dual-coding theory motivates linking verbal material with imagery when the meaning is imageable. It does not imply that adding any picture or sound guarantees better learning. Abstract meanings and discourse markers may need a concise verbal cue instead of a forced image. Images must be relevant and clear enough to identify the intended concept.

### 5. Space practice and refine

Anki schedules repeated retrieval over time. Spaced practice has strong support for long-term verbal retention. A card should be corrected when its prompt does not naturally lead to the target, when a chunk is unnatural, or when the answer leaks onto the front. Updating an existing note must preserve its identity and review schedule.

## Card specification

### Ordinary words and chunks

**Front**

- Heading: `单词和chunk`.
- Full target word or chunk, with its own playback.
- One or two common, scenario-related chunks, each with independent playback.
- A divider.
- A concrete English scenario, normally two or three lines, with people, place, action, change, and the moment that prompts speech.
- An independent question such as `What would you say?`.
- No answer, translation of the target, answer audio, or answer-revealing definition.

**Back**

- Heading: `单词和chunk对应的概念实体`.
- One clear target-specific concept image. A second image is allowed only when it directly depicts a related chunk. No standalone scenario image.
- Heading: `情境下的自然表达`.
- The most likely natural, common spoken response for that situation, plus useful example sentences and independent audio.
- Every chunk shown on the front must occur naturally in the answer. A single audio file has only one player on each card face.

**Pronunciation**

Use `edge-tts`, voice `en-GB-SoniaNeural`, at `rate='+0%'`. Generate separate complete audio for the target, each chunk, each answer sentence, and each example sentence. Keep natural stress, reduction, linking, and pauses. A changed sentence needs matching regenerated audio.

### Function words

Use these confirmed labels:

| Target | Trigger label | Functional cue |
|---|---|---|
| `but` | `Important!` | The main point follows |
| `although` | `I admit it—but…` | Acknowledge first, then turn |
| `now as` | `Listen next!` | Attend to the next stage or background |
| `however` | `Think again!` | Reconsider or reverse the previous point |
| `therefore` | `Take action!` | Conclusion or action follows |
| `otherwise` | `Warning!` | Attend to the consequence |
| `for example` | `Look here!` | A specific example follows |

Show the target on the front with its pronunciation and ask for a quick reaction; do not reveal the label. On the back, give the short English trigger, a typical use, and examples with separate audio. These labels are retrieval cues, not dictionary definitions. Interpret `now as` from the sentence in which it occurs. The normal concept-image requirement does not apply to function words when no meaningful concrete entity exists.

## Notion and Anki responsibilities

- **Notion** stores the searchable personal dictionary, original notes, corrected interpretations, examples, source stories, images, audio references, and synchronization state. Use one clickable child page per target. Keep the homepage short, with a dedicated new-content inbox, a database link, and a small sync overview.
- **Anki** stores the reviewable cards and schedules active retrieval over time.
- **The skill** moves data between them: inspect the latest page and schema, process every eligible item, prepare and validate a batch, ensure AnkiConnect is ready, deduplicate by the complete normalized target, write media and cards, verify results, write Note IDs and status back to Notion, fetch again, and reconcile.

Every new item is eligible for a card unless the learner explicitly excludes it. Categories such as “recognize only” describe priority; they do not silently drop the item. Do not clear source notes or mark pages synced until Anki fields and all referenced media are verified. Updates keep the existing Note ID and review schedule. Duplicate Notion pages are reported as suggestions; they are not automatically deleted or merged.

## Why the method uses these choices

- Personal context preserves why the word mattered and keeps the learner's own interpretation visible beside any correction.
- Chunk learning connects word form to the collocations and grammatical patterns used in actual production.
- A scenario plus an open question prompts active recall of an expression under a cue similar to the learner's intended use.
- Relevant imagery and separate pronunciation audio offer additional retrieval cues without substituting for semantic understanding or practice.
- Spaced retrieval allocates review over time and reduces reliance on rereading.
- Full-target deduplication and post-write checks protect the accumulated dictionary and prevent an apparent sync from hiding missing cards or media.

## Evidence and limits

- **Retrieval practice:** Roediger and Karpicke found that testing can improve delayed retention relative to repeated study for prose material. The scenario question applies retrieval practice; their study did not test this exact vocabulary-card design.
- **Spacing:** Cepeda and colleagues' quantitative review supports distributed rather than massed practice across verbal-recall studies. Anki is the scheduling tool in this workflow; its use does not guarantee that every interval or item is optimal.
- **Transfer and cue match:** Morris, Bransford, and Franks showed that memory performance depends partly on the relation between encoding task and later test. Pan and Rickard's meta-analysis found that transfer from testing varies across task types and cues. Scenario cards aim for relevant near-transfer, but cannot replace varied real use.
- **Imagery:** Paivio's dual-coding account motivates linking verbal and nonverbal representations. This supports meaning-relevant images as a design rationale, not a blanket promise that more modalities always improve learning.
- **Multiword units:** Nation treats multiword units as a vocabulary-learning topic in their own right. The workflow therefore stores natural chunks as targets when they capture a useful expression or collocation.

## References

1. Roediger, H. L., & Karpicke, J. D. (2006). Test-enhanced learning: Taking memory tests improves long-term retention. *Psychological Science, 17*(3), 249–255. [doi:10.1111/j.1467-9280.2006.01693.x](https://doi.org/10.1111/j.1467-9280.2006.01693.x)
2. Cepeda, N. J., Pashler, H., Vul, E., Wixted, J. T., & Rohrer, D. (2006). Distributed practice in verbal recall tasks: A review and quantitative synthesis. *Psychological Bulletin, 132*(3), 354–380. [doi:10.1037/0033-2909.132.3.354](https://doi.org/10.1037/0033-2909.132.3.354)
3. Morris, C. D., Bransford, J. D., & Franks, J. J. (1977). Levels of processing versus transfer appropriate processing. *Journal of Verbal Learning and Verbal Behavior, 16*(5), 519–533. [doi:10.1016/S0022-5371(77)80016-9](https://doi.org/10.1016/S0022-5371(77)80016-9)
4. Pan, S. C., & Rickard, T. C. (2018). Transfer of test-enhanced learning: Meta-analytic review and synthesis. *Psychological Bulletin, 144*(7), 710–756. [doi:10.1037/bul0000151](https://doi.org/10.1037/bul0000151)
5. Paivio, A. (1991). Dual coding theory: Retrospect and current status. *Canadian Journal of Psychology/Revue canadienne de psychologie, 45*(3), 255–287. [doi:10.1037/h0084295](https://doi.org/10.1037/h0084295)
6. Nation, I. S. P. (2022). *Learning Vocabulary in Another Language* (3rd ed.). Cambridge University Press. [Book and chapter information](https://www.cambridge.org/core/books/learning-vocabulary-in-another-language/97C1293EBC8716EA70B77626E00740AA)

## Privacy

This public repository contains the reusable method and skill only. Do not commit personal Notion page or database IDs, private vocabulary records, local profiles, API keys, Anki collection data, or generated personal card media.
