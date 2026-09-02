package com.ruvees.bsmart

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.AdChoicesView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory

class AdMobNativeAdFactory(private val context: Context) : NativeAdFactory {
    companion object {
        const val factoryId = "bsmart_native_ad_factory"
    }

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val adView = LayoutInflater.from(context)
            .inflate(R.layout.native_admob_ad, null) as NativeAdView

        val headlineView = adView.findViewById<TextView>(R.id.native_ad_headline)
        val bodyView = adView.findViewById<TextView>(R.id.native_ad_body)
        val callToActionView =
            adView.findViewById<Button>(R.id.native_ad_call_to_action)
        val iconView = adView.findViewById<ImageView>(R.id.native_ad_icon)
        val advertiserView =
            adView.findViewById<TextView>(R.id.native_ad_advertiser)
        val mediaView = adView.findViewById<MediaView>(R.id.native_ad_media)
        val adChoicesView = adView.findViewById<AdChoicesView>(R.id.native_ad_choices)

        adView.headlineView = headlineView
        adView.bodyView = bodyView
        adView.callToActionView = callToActionView
        adView.iconView = iconView
        adView.advertiserView = advertiserView
        adView.mediaView = mediaView
        adView.adChoicesView = adChoicesView

        headlineView.text = nativeAd.headline
        bodyView.text = nativeAd.body
        callToActionView.text = nativeAd.callToAction
        advertiserView.text = nativeAd.advertiser

        bodyView.visibility = if (nativeAd.body.isNullOrBlank()) View.GONE else View.VISIBLE
        callToActionView.visibility =
            if (nativeAd.callToAction.isNullOrBlank()) View.GONE else View.VISIBLE
        advertiserView.visibility =
            if (nativeAd.advertiser.isNullOrBlank()) View.GONE else View.VISIBLE

        val icon = nativeAd.icon
        if (icon != null) {
            iconView.setImageDrawable(icon.drawable)
            iconView.visibility = View.VISIBLE
        } else {
            iconView.visibility = View.GONE
        }

        mediaView.setMediaContent(nativeAd.mediaContent)
        adView.setNativeAd(nativeAd)

        return adView
    }
}