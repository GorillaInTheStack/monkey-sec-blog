---
title: "What got Sony's playstation 3 pwned?"
subtitle: "Tails of ECDSA from the wild"
date: 2025-04-13
description: "We discuss the asymmetric signature algorithm ECDSA and its nonce reuse flaw that led to Sony's PS3 getting pwned."
tags: ["ECDSA", "PKI", "bitcoin", "nonce", "vulnerability", "code"]
categories: ["Cryptography"]
authors: ["Sam"]
draft: false
toc:
  enable: true
  auto: true
---
<!--more-->
## Some Background

Back when PS3 came out, Sony decided to not support linux homebrew on their machines.
So in order to do so, they devised some secure boot setup where they signed "approved"
software and firmware. It was all nice and dandy until a group of our fellow nerds from
the jungle realized the fellas from Sony who were using ECDSA to sign their stuff were
using a *static* nonce for the algorithm. This is a big no no for ECDSA and it's probably
one of the first things you learn about when studying ECDSA.

In this post we will explain why is this a no no, and we will show how it can be exploited.

## What is ECDSA?

The [Elliptic Curve Digital Signature Algorithm (ECDSA)](https://en.wikipedia.org/wiki/Elliptic_Curve_Digital_Signature_Algorithm) is wildly used on the web for a variety of protocols and in different use cases.
It's an asymmetric signature algorithm so naturally it uses a key pair, A *public
key* noted as **PK** and a *private key* noted as **SK** (for secret key, because
it is supposed to be secret 🧠)

As the name suggests, this algorithm is used to sign information and to verify
the authenticity of information signed. A digital signature stems from the same
ideas surrounding traditional signatures. They are used to establish trust.

I will not discuss the underlying mathematics behind this algorithm beyond
high-school level mathematics. You can check out the wiki page to learn more
about [elliptic curves over finite fields](https://en.wikipedia.org/wiki/Elliptic_curve#Algorithms_that_use_elliptic_curves) and how they create a system that
is used to create cryptographic algorithms with elliptic curve arithmetics.

What is important for us (programmers) is to know how this algorithm works
on a high level. Additionally, to know what is it about it that makes it secure.

Let's take a look at how this algorithm function with two participants
involved. Take a look at the following diagram.

### ECDSA High Level Flow {#ecdsa-diagram}

On a high level, the algorithm looks like this:
{{< mermaid >}}sequenceDiagram
    actor Alice
    actor Bob
    Note left of Alice: Generate key pair PK, SK
    Alice->>Bob: "Hi Bob", sign("Hi Bob", SK)
    Note right of Bob: Verify signature with PK
    Bob->>Alice: "Hi Alice, I got your message!"
{{< /mermaid >}}

{{< admonition type=note title="About the theory" open=false >}}
If you're here for the practical stuff (i.e, how to exploit this).
Feel free to skip all the theoretical explanations by going [here](#exploit). You don't need
to understand any of this in order to be able to exploit the vulnerability.

That being said, I recommend going through it. It will give you a deeper
understanding. I will keep it strictly to what is relevant.
{{< /admonition >}}

Let's zoom in a bit now and reveal a little more details about this
algorithm. This will help us visualize what the issue actually is.

{{< mermaid >}}sequenceDiagram
    actor Alice
    actor Bob
    Note left of Alice: Generate a random number x such that -> $$SK = x$$
    Note left of Alice: Calculate -> $$PK = x * G \pmod p$$
    Note left of Alice: Generate random number k -> *The nonce*
    Note left of Alice: $$r = ((k * G) \pmod p)_x$$
    Note left of Alice: $$s = (k^{-1} * (H(m) + SK * r)) \pmod p$$
    Alice->>Bob: "Hi Bob", (r, s) -> *These two values are the signature*
    Note right of Bob: Verify signature with PK -> *exact details is irrelevant for our topic*
    Bob->>Alice: "Hi Alice, I got your message!"
{{< /mermaid >}}

{{< admonition type=info title="Symbols explanation" open=true >}}
Let me explain some of these magical symbols I just conjured up.

- **PK**: Public key
- **SK** or **x**: Secret key, also known as private key or signing key. Very famous fella.
- **k**: A random number that needs to be unique and uniformly random. That's the **nonce**.
It's also supposed to be a secret.
- **G**: A point (x, y) on an elliptic curve that is a *generator*. It's called a *base point*. It's not a secret.
- **mod**: The modulus operator. Also known as the remainder. You might know it as %.
- **p**: A very big prime number to avoid small subgroups attacks.
Usually standardized. In EC lingo, it's called a curve order. It's the
number of all points in the subgroup.
- **r**: First part of the signature in ECDSA. It's the x-coordinate of the
result point of the right hand side.
- **H(m)**: A hash of the message sent. In our example, it's a hash of "Hi Bob".
You can assume it's SHA256.
- **s**: The second part of the signature.

As you see above, r and s are sent together in cleartext with the message as
they're the signature.

**p** and **G** are public. They're known to any listening party.

For the exploit, all you need to worry about is **x** and **k**.
{{< /admonition >}}

{{< admonition type=tip title="The security of EC" open=false >}}

The reason why the private key $PK = x * G \pmod p$ is secure, because it is
hard to calculate x by knowing G and p. This is called the [Elliptic curve discrete logarithm problem.](https://eitca.org/cybersecurity/eitc-is-acc-advanced-classical-cryptography/elliptic-curve-cryptography/introduction-to-elliptic-curves/examination-review-introduction-to-elliptic-curves/what-is-the-elliptic-curve-discrete-logarithm-problem-ecdlp-and-why-is-it-difficult-to-solve/)
It is hard *for now*, until the quantum computing nation attacks.

{{< /admonition >}}

## The Nonce Reuse Issue

Given the abbreviated normal flow we just saw, let's get down to business and
look at the situation where the issue comes alive.

### From a Theoretical Perspective

Consider the following situation. We have Alice and Bob trying to chat, and
Sam over here in the middle listening. Alice does an oopsie and reuses the nonce **k** even
though she is not supposed to. Let's visualize what's happening.

{{< mermaid >}}sequenceDiagram
    actor Alice
    actor Sam
    actor Bob
    Note right of Sam: This guy listening on the network
    Note left of Alice: Same initialization as before
    Alice->>Bob: "Hi Bob",
    Alice->>Bob: $$r_1= ((k * G) \pmod p )_x$$,
    Alice->>Bob: $$s_1= (k^{-1} * (H(m_1) + SK * r)) \pmod p$$
    Note left of Alice: This is the first message $$m_1$$ with nonce k
    Note right of Bob: Verify signature with PK -> *exact details is irrelevant for our topic*
    Bob->>Alice: "Hi Alice, I got your message!"
    Alice->>Bob: "How are you?",
    Alice->>Bob: $$r_2= ((k * G) \pmod p )_x$$,
    Alice->>Bob: $$s_2= (k^{-1} * (H(m_2) + SK * r)) \pmod p$$
    Note left of Alice: This is the second message $$m_2$$ with same nonce k
    Note right of Bob: Verify signature with PK -> *exact details is irrelevant for our topic*
    Bob->>Alice: "I'm good!"
{{< /mermaid >}}

Alice done messed up now. Let's see why real quick.

{{< admonition title="About the math" open=false >}}

It's about to get a little mathy. Do not be afraid.
We will just be solving a system of two linear equations.
You might remember this from school. If not, [check it out](https://en.wikipedia.org/wiki/System_of_linear_equations).
We do not need the math that ECDSA based on in order to exploit the issue.
Trust me, it ain't that deep.

{{< /admonition >}}

{{< admonition type=abstract title="The current knowns" open=true >}}

Mr Sam, who has been listening in to the conversation, has been able to gather:

- **G** (it's public)
- **p** (it's public)
- $r_1$ (part of the signature 1)
- $r_2$ (part of the signature 2)
- $s_1= (k^{-1} * (H(m_1) + SK * r)) \pmod p$ (second part of the signature 1 with hash of message 1)
- $s_2= (k^{-1} * (H(m_2) + SK * r)) \pmod p$ (second part of the signature 2 with hash of message 1)

The last two equations are interesting. We can use methods of solving equations in order to isolate variables.
Our objectives is find out what the nonce **k** value is, and more importantly figure out the secret key **SK**.

{{< /admonition >}}

{{< admonition type=example title="Finding the nonce k" open=true >}}

We will start by subtracting the two equations $s_1 - s_2$

- $ s_1 - s_2 = (k^{-1} * (H(m_1) + SK * r)) - (k^{-1} * (H(m_2) + SK * r)) \pmod p$

The SK and r will cancel out because they're the same value. We end up with

- $ s_1 - s_2 = (k^{-1} * H(m_1) - k^{-1} * H(m_2)) \pmod p $

We can take $k^{-1}$ as a common factor

- $ s_1 - s_2 = (k^{-1} * (H(m_1) - H(m_2))) \pmod p$

Now we divide by $ s_1 - s_2 $ and multiply by $k$, this is to isolate k.

- $\textcolor{pink}{k = \dfrac{H(m_1) - H(m_2)}{s_1 - s_2} \pmod p}$

All the variables in the right hand side are known. We got both $s_1, s_2$ from listening
to the exchange. We can also easily calculate $H(m_1), H(m_2)$ by running the hash function
on the message ourself.

We just found out what the nonce value is!
That ain't that important though, but we can use it to find the private key next.
{{< /admonition >}}

{{< admonition type=example title="Finding the secret key SK" open=true >}}

We now know the value of the nonce **k**. We can use this to find the secret key / private key / signing key.
We can take one of the equations and isolate **SK**. Let's take $s_1$.

- $s_1 = (k^{-1} * (H(m_1) + SK * r)) \pmod p$
- $s_1 * k = (H(m_1) + SK * r) \pmod p$
- $s_1 * k - H(m_1) = SK * r \pmod p$
- $\textcolor{red}{SK = \dfrac{s_1 * k - H(m_1)}{r}}$

Again, all the variables on the right hand side are known.
We know **r** and $s_1$ from listening to the conversation.
We can calculate $H(m_1)$ ourselves and we already found the nonce
**k** in the previous step.

**We just revealed Alice's private key!**

{{< /admonition >}}

Refer to [this paper](https://christian-rossow.de/publications/btcsteal-raid2018.pdf) for more mathematics.

### From a Practical Perspective (Applied Cryptography)

#### The mistake

Let me show you what this mistake looks like in code.
{{< tabs >}}

{{% tab title="Nonce reuse mistakes" %}}

```python
from ecdsa import SigningKey, SECP256k1, util
from hashlib import sha256

# https://ecdsa.readthedocs.io/en/latest/quickstart.html#getting-started
# Not to be used in production obviously

msg1 = b"hello alice"
msg2 = b"How are you doing today?"
with open("msg1.txt", "wb") as f:
    f.write(msg1)
with open("msg2.txt", "wb") as f:
    f.write(msg2)

hash_msg1 = int.from_bytes(sha256(msg1).digest(), "big")
hash_msg2 = int.from_bytes(sha256(msg2).digest(), "big")

signing_key_handler = SigningKey.generate(curve=SECP256k1)
verifying_key = signing_key_handler.verifying_key
secret_key = signing_key_handler.privkey.secret_multiplier
n = signing_key_handler.curve.order

with open("public.pem", "wb") as f:
    f.write(verifying_key.to_pem())

# BAD: Reused nonce
k = 0xBADBADBADBADBADBADBADBADBADBADBADBADBADBADBADBADBADBADBADBADBEEF

r = (signing_key_handler.curve.generator * k).x() % n
s1 = (pow(k, -1, n) * (hash_msg1 + r * secret_key)) % n
s2 = (pow(k, -1, n) * (hash_msg2 + r * secret_key)) % n

sig1_der = util.sigencode_der(r, s1, n)
sig2_der = util.sigencode_der(r, s2, n)

with open("sig1.der", "wb") as f:
    f.write(sig1_der)
with open("sig2.der", "wb") as f:
    f.write(sig2_der)

```

```go
package main

import (
        "crypto/ecdsa"
        "crypto/elliptic"
        "crypto/rand"
        "crypto/sha256"
        "crypto/x509"
        "encoding/asn1"
        "encoding/pem"
        "fmt"
        "math/big"
        "os"
)

type ecdsaSignature struct {
        R, S *big.Int
}

func savePEM(filename string, der []byte, typ string) {
        block := &pem.Block{Type: typ, Bytes: der}
        os.WriteFile(filename, pem.EncodeToMemory(block), 0644)
}

func main() {
        curve := elliptic.P256()

        private_key, _ := ecdsa.GenerateKey(curve, rand.Reader)
        public_key := &private_key.PublicKey

        //      privBytes, _ := x509.MarshalECPrivateKey(priv)

        pubBytes, err := x509.MarshalPKIXPublicKey(public_key)
        if err != nil {
                panic(err)
        }

        //      savePEM("private.pem", privBytes, "EC PRIVATE KEY")
        savePEM("public.pem", pubBytes, "PUBLIC KEY")

        msg1 := []byte("hello alice")
        msg2 := []byte("What's good with you?")
        os.WriteFile("msg1.txt", msg1, 0644)
        os.WriteFile("msg2.txt", msg2, 0644)

        hash_msg1 := sha256.Sum256(msg1)
        hash_msg2 := sha256.Sum256(msg2)

        // BAD: static nonce reuse here
        k := new(big.Int)
        k.SetString("BADBADBADBADBADBADBADBADBADBADBADBADBADBADBADBADBADBADBEEF", 16)
        n := curve.Params().N
        k.Mod(k, n)

        // r = (k*G).X mod n
        x, _ := curve.ScalarBaseMult(k.Bytes())
        r := new(big.Int).Mod(x, n)

        bytesToInt := func(hash []byte) *big.Int {
                return new(big.Int).SetBytes(hash)
        }

        kInv := new(big.Int).ModInverse(k, n)

        // s = k^-1 (hash_msg + r*d) mod n
        calcSig := func(hash []byte) *big.Int {
                tmp := new(big.Int).Mul(r, private_key.D)
                tmp.Add(tmp, bytesToInt(hash))
                tmp.Mod(tmp, n)
                s := new(big.Int).Mul(kInv, tmp)
                return s.Mod(s, n)
        }

        s1 := calcSig(hash_msg1[:])
        s2 := calcSig(hash_msg2[:])

        sig1Der, _ := asn1.Marshal(ecdsaSignature{r, s1})
        sig2Der, _ := asn1.Marshal(ecdsaSignature{r, s2})
        os.WriteFile("sig1.der", sig1Der, 0644)
        os.WriteFile("sig2.der", sig2Der, 0644)

        fmt.Println("[+] Signed messages with reused nonce k")
}
```

{{% /tab %}}

{{< /tabs >}}

Find All the code above on [Github](https://github.com/GorillaInTheStack/sec-experiements/tree/main/crypto/ecdsa_nonce_reuse/problem_example)

You can also verify the signature with openssl:

```bash
openssl dgst -sha256 -verify public.pem -signature sig1.der msg1.txt

```

{{< admonition type=danger title="Beware" open=true >}}
Don't try anything funny with crypto APIs in anything serious.
Always use abstracted libraries.
{{< /admonition >}}

{{< admonition type=info title="Hmmm" open=true >}}
The code above is not necessarily how the problem manifests.
Well, except for embedded scenarios where you are directly interacting
with the cryptographic accelerator. In that case, you are handling everything
yourself, usually in C.

You would usually be using libraries that abstract all this nonce none sense.
The issue there is either:

- The library allows the developer to set the nonce. The dev is confused about it and end up misusing it.
- The library uses predictable easy to guess nonces, or the nonces repeat after a while or when the service
is forced to restart.
{{< /admonition >}}

{{< admonition type=note title="DER" open=true >}}
DER stands for Distingushed Encoding Rules. They're part of a notation called ASN.1.
It's basically a standard way to format and encode cryptography materials so that
we can use them with several tools and technologies.
Read more about it at: [Buchanan, William J (2026). ASN.1: DER and PEM formats. Asecuritysite.com.](https://asecuritysite.com/ecc/sigs5)
{{< /admonition >}}

#### Exploitation {#exploit}

Let's see how we can recover the signing key (private key) with code.
As earlier, we have as input:

- The two messages msg1 and msg2
- The two signatures r1, s1 and r2, s2

All of the example mistakes above provide these so our exploit should
work for all of them.

{{< tabs >}}
{{% tab title="Exploit" %}}

```python
from ecdsa import SECP256k1, NIST256p, SigningKey, util
from hashlib import sha256
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives.asymmetric import ec


def read_der_signature(path):
    with open(path, "rb") as f:
        sig_der = f.read()
    r, s = util.sigdecode_der(sig_der, SECP256k1.order)
    return r, s


def read_msg(path):
    with open(path, "rb") as f:
        return f.read()


def get_curve_from_pem(path):
    with open(path, "rb") as f:
        pub_key = serialization.load_pem_public_key(f.read(), backend=default_backend())

    if isinstance(pub_key.curve, ec.SECP256K1):
        print("[+] Detected curve: secp256k1")
        return SECP256k1
    elif isinstance(pub_key.curve, ec.SECP256R1):  # aka P-256
        print("[+] Detected curve: NIST P-256")
        return NIST256p
    else:
        raise ValueError("Unsupported curve")


msg1 = read_msg("msg1.txt")
msg2 = read_msg("msg2.txt")

hash_msg1 = int.from_bytes(sha256(msg1).digest(), "big")
hash_msg2 = int.from_bytes(sha256(msg2).digest(), "big")

r1, s1 = read_der_signature("sig1.der")
r2, s2 = read_der_signature("sig2.der")

# This is actually a visual indication of this problem.
# You will notice that the first parts of the signatures (the r) are the same
# for two different messages. This is because the same nonce k is used to calcualte
# the r part.
assert r1 == r2, "Reused nonce requires both signatures to have same r"
r = r1

curve = get_curve_from_pem("public.pem")
n = curve.order
k = ((hash_msg1 - hash_msg2) * pow(s1 - s2, -1, n)) % n
private_key = ((s1 * k - hash_msg1) * pow(r, -1, n)) % n

print(f"[+] Reused nonce (k): {hex(k)}")
print(f"[+] Recovered private key (d): {hex(private_key)}")

recovered_sk = SigningKey.from_secret_exponent(private_key, curve=curve)
with open("recovered_private.pem", "wb") as f:
    f.write(recovered_sk.to_pem())

evil_msg = b"ecdsa pwned"
evil_sig = recovered_sk.sign_deterministic(
    evil_msg, hashfunc=sha256, sigencode=util.sigencode_der
)

with open("evil.sig", "wb") as f:
    f.write(evil_sig)
with open("evil_msg.txt", "wb") as f:
    f.write(evil_msg)

print("[+] Recovered private key saved to recovered_private.pem")

```

{{% /tab %}}
{{< /tabs >}}
Find the exploit above on [Github](https://github.com/GorillaInTheStack/sec-experiements/tree/main/crypto/ecdsa_nonce_reuse/exploit)

You can verify that our evil message's signature is verifiable with the
public key (verifying key) with openssl too:

```bash
openssl dgst -sha256 -verify public.pem -signature evil.sig evil_msg.txt
Verified OK

```

GGs to Alice.

### Why is this a problem again?

Well, we can sign whatever we want now and impersonate Alice.
Everybody will verify with her public key and will think everything
is coming from her.

The actual impact of this problem depends on what protocol this
algorithm is used in. Let's explore some:

- If Alice is signing her bitcoin transactions with this key, attacker can steal her money.
- If Alice is signing her firmware with this key in order to combat piracy, the pirates will sign their stuff too now.
- If Alice is signing her key material for TLS key exchange, attacker can now become an [active MiTM](https://en.wikipedia.org/wiki/Man-in-the-middle_attack).
- If Alice is a CA signing certificates for websites, attacker can now create any certificate they want.
- Other tech potentially affected: SSH, Oauth, JWT, Email and Document signing, etc.

Check out this [CTF challenge](https://0xswitch.fr/CTF/ecw-2020-final-ecdsa-nonce-reuse) from 2020 for a voting system misusing ECDSA.

## That's all folks

For more potential issues with ECDSA, check out this paper: [ECDSA Cracking Methods](https://arxiv.org/abs/2504.07265)
A lot of them revolve around the nonce too.

{{< typeit >}}
Stay curious gang.
{{< /typeit >}}
