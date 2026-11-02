package com.handytools.app.tools.power

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * AES-256-GCM encryption backed by a non-exportable key in the Android Keystore. The key never
 * leaves secure hardware, so vault files on disk are unreadable without this device. Each blob stores
 * its own IV: [ivLen][iv][ciphertext+tag].
 */
object VaultCrypto {
    private const val KEY_ALIAS = "tenzy_vault_key_v1"
    private const val ANDROID_KEYSTORE = "AndroidKeyStore"
    private const val TRANSFORM = "AES/GCM/NoPadding"

    private fun secretKey(): SecretKey {
        val ks = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        (ks.getEntry(KEY_ALIAS, null) as? KeyStore.SecretKeyEntry)?.let { return it.secretKey }
        val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        gen.init(
            KeyGenParameterSpec.Builder(KEY_ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build()
        )
        return gen.generateKey()
    }

    fun encrypt(plain: ByteArray): ByteArray {
        val c = Cipher.getInstance(TRANSFORM); c.init(Cipher.ENCRYPT_MODE, secretKey())
        val iv = c.iv
        val ct = c.doFinal(plain)
        val out = ByteArray(1 + iv.size + ct.size)
        out[0] = iv.size.toByte()
        System.arraycopy(iv, 0, out, 1, iv.size)
        System.arraycopy(ct, 0, out, 1 + iv.size, ct.size)
        return out
    }

    fun decrypt(data: ByteArray): ByteArray {
        val ivLen = data[0].toInt()
        val iv = data.copyOfRange(1, 1 + ivLen)
        val ct = data.copyOfRange(1 + ivLen, data.size)
        val c = Cipher.getInstance(TRANSFORM)
        c.init(Cipher.DECRYPT_MODE, secretKey(), GCMParameterSpec(128, iv))
        return c.doFinal(ct)
    }
}
