package jp.feswave.feswave_android

import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "jp.feswave/identity").setMethodCallHandler { call, result ->
            if (call.method != "google") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            scope.launch {
                try {
                    val option = GetSignInWithGoogleOption.Builder(requireNotNull(call.argument<String>("clientId")))
                        .setNonce(requireNotNull(call.argument<String>("nonce"))).build()
                    val request = GetCredentialRequest.Builder().addCredentialOption(option).build()
                    val response = CredentialManager.create(this@MainActivity).getCredential(this@MainActivity, request)
                    result.success(GoogleIdTokenCredential.createFrom(response.credential.data).idToken)
                } catch (e: Exception) {
                    result.error("GOOGLE_LOGIN", e.localizedMessage, null)
                }
            }
        }
    }
    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }
}
