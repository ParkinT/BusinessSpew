# Business Spew Generator

The BS Generator creates blocks of valid English language sentences comprised solely of jargon, slang and nonsense. The __Symbiotic Highly-Intelligent Type__ generator has the capability to create phrases and sentences that conform properly to linguistic and grammatical rules.

> BusinessSpew(BS) is that seemingly endless flow of acronyms, jargon and buzzwords that sneak into almost ALL business conversations.  You see it in memos, reports, email messages and even hear it in telephone "con calls". 

We have had fun developing this but the most fun is when you slip a few of these sentences in on unsuspecting colleagues as part of some 'real' business correspondence!  Pin up an OFFICIAL MEMO on the bulletin board and watch the heads bob in agreement as they contemplate these deep business concepts.
BusinessSpew is active and live at http://BS.LeveragedSynergies.com  It was instantiated as my entry for the [Rails Rumble 2012](http://railsrumble.com/entries/66-business-spew-generator).

## BusinessSpew API The API can be called to consume BusinessSpew sentences.
``` 
 bs.leveragedsynergies.com/api/4/2
```
The result is returned as JSON

 This will return __2__ paragraphs with __4__ sentences in each (in JSON format).
  The default (if no number is defined) is one.  

Optionally, you can include a Report Title as the last parameter.

```
  bs.leveragedsynergies.com/api/4/2/Report%20Title
```

  [ x ] Note that the text **must be** URL encoded.

### Tweet your BS The BusinessSpew Generator can provide a Twitter-friendly sentence with a call like this:

```
 bs.leveragedsynergies.com/api/tweet

```
#### Here is an example generated by the BSG: 

> Stop what you are doing and give me a status report on how you value strategic customized skill sets! Our strategy requires a zero-deviation precision focus, and we must harbor your defacto committees. Our solution is that we always amass median unary responsibilities!  Unilaterally, we should e-cumulate shifted outside-in action-items. Logically, we must self-direct all vertical webifications.


#### BusinessSpew is now a Slack Bot
Install the [BS-Bot](https://github.com/ParkinT/bs-bot) in your Slack group and have fun generating **pure BS**

---

### The origins of BusinessSpew 

The concept of BusinessSpew originated many years ago.  Back in the days before the Internet, I wrote a small DOS application called 'Jive'.  It was "The World's First True WORD Processor" because it would convert any text you fed it to a slang (at the time called Ebonics).
As an active member of the "corporate world", my dear friend Wilson Rogers took the idea and constructed a more Dilbert-esque version of my idea as BusinessSpew.
That was written entirely in Javascript and lived on (then his) website, LeveragedSynergies.

Leukemia took my dear friend from us in the early 2000s.  Wilson was the author of many Shareware applications.  One of then still in use today - and with a loyal following of users - is [WRBBS](http://software.bbsdocumentary.com/IBM/DOS/WRBBS/).  It is a very robust Electronic Bulletin Board System.
