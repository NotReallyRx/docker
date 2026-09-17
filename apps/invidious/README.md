# Invidious 

Invidious is an open-source, privacy-focused frontend for YouTube

To Install please read the docs


 [DOCS](https://docs.invidious.io/installation/#docker)


Or my step-by-step

1. First run `git clone https://github.com/iv-org/invidious.git`
2. Then run:
```bash
pwgen 16 1 # 1st step for Invidious (HMAC_KEY)
pwgen 16 1 # 2nd step for Invidious companion (invidious_companion_key)
```

3. After that copy each value to the env - the 1st one going to `HMAC_KEY` and the second to `COMPANION_KEY`
4. set the password and usernameand done!