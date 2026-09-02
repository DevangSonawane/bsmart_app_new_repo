import Flutter
import UIKit
import google_mobile_ads

final class BSmartNativeAdFactory: NSObject, FLTNativeAdFactory {
  func createNativeAd(
    _ nativeAd: GADNativeAd,
    customOptions: [AnyHashable: Any]? = nil
  ) -> GADNativeAdView {
    let adView = GADNativeAdView()
    adView.translatesAutoresizingMaskIntoConstraints = false

    let container = UIView()
    container.translatesAutoresizingMaskIntoConstraints = false
    container.backgroundColor = .secondarySystemBackground
    container.layer.cornerRadius = 18
    container.layer.masksToBounds = true
    adView.addSubview(container)

    NSLayoutConstraint.activate([
      container.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
      container.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
      container.topAnchor.constraint(equalTo: adView.topAnchor),
      container.bottomAnchor.constraint(equalTo: adView.bottomAnchor),
    ])

    let adChoicesView = GADAdChoicesView()
    adChoicesView.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(adChoicesView)

    let sponsoredLabel = UILabel()
    sponsoredLabel.translatesAutoresizingMaskIntoConstraints = false
    sponsoredLabel.text = "Sponsored"
    sponsoredLabel.font = .systemFont(ofSize: 11, weight: .bold)
    sponsoredLabel.textColor = .secondaryLabel
    container.addSubview(sponsoredLabel)

    let headlineLabel = UILabel()
    headlineLabel.translatesAutoresizingMaskIntoConstraints = false
    headlineLabel.numberOfLines = 2
    headlineLabel.font = .systemFont(ofSize: 18, weight: .bold)
    headlineLabel.textColor = .label
    container.addSubview(headlineLabel)

    let mediaView = GADMediaView()
    mediaView.translatesAutoresizingMaskIntoConstraints = false
    mediaView.backgroundColor = .tertiarySystemFill
    mediaView.clipsToBounds = true
    mediaView.layer.cornerRadius = 14
    container.addSubview(mediaView)

    let bodyLabel = UILabel()
    bodyLabel.translatesAutoresizingMaskIntoConstraints = false
    bodyLabel.numberOfLines = 3
    bodyLabel.font = .systemFont(ofSize: 14, weight: .regular)
    bodyLabel.textColor = .secondaryLabel
    container.addSubview(bodyLabel)

    let footerStack = UIStackView()
    footerStack.translatesAutoresizingMaskIntoConstraints = false
    footerStack.axis = .horizontal
    footerStack.alignment = .center
    footerStack.spacing = 10
    container.addSubview(footerStack)

    let iconView = UIImageView()
    iconView.translatesAutoresizingMaskIntoConstraints = false
    iconView.contentMode = .scaleAspectFill
    iconView.clipsToBounds = true
    iconView.layer.cornerRadius = 8
    iconView.backgroundColor = .tertiarySystemFill
    NSLayoutConstraint.activate([
      iconView.widthAnchor.constraint(equalToConstant: 40),
      iconView.heightAnchor.constraint(equalToConstant: 40),
    ])
    footerStack.addArrangedSubview(iconView)

    let advertiserLabel = UILabel()
    advertiserLabel.translatesAutoresizingMaskIntoConstraints = false
    advertiserLabel.numberOfLines = 2
    advertiserLabel.font = .systemFont(ofSize: 13, weight: .semibold)
    advertiserLabel.textColor = .secondaryLabel
    footerStack.addArrangedSubview(advertiserLabel)

    let spacer = UIView()
    spacer.translatesAutoresizingMaskIntoConstraints = false
    spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
    spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    footerStack.addArrangedSubview(spacer)

    let ctaButton = UIButton(type: .system)
    ctaButton.translatesAutoresizingMaskIntoConstraints = false
    ctaButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
    ctaButton.setContentHuggingPriority(.required, for: .horizontal)
    ctaButton.setContentCompressionResistancePriority(.required, for: .horizontal)
    ctaButton.backgroundColor = .systemBlue
    ctaButton.setTitleColor(.white, for: .normal)
    ctaButton.layer.cornerRadius = 12
    ctaButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
    footerStack.addArrangedSubview(ctaButton)

    NSLayoutConstraint.activate([
      adChoicesView.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
      adChoicesView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),

      sponsoredLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
      sponsoredLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),

      headlineLabel.topAnchor.constraint(equalTo: sponsoredLabel.bottomAnchor, constant: 8),
      headlineLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
      headlineLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),

      mediaView.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 10),
      mediaView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
      mediaView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
      mediaView.heightAnchor.constraint(equalToConstant: 200),

      bodyLabel.topAnchor.constraint(equalTo: mediaView.bottomAnchor, constant: 10),
      bodyLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
      bodyLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),

      footerStack.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 12),
      footerStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
      footerStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
      footerStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14),
    ])

    adView.headlineView = headlineLabel
    adView.bodyView = bodyLabel
    adView.mediaView = mediaView
    adView.iconView = iconView
    adView.advertiserView = advertiserLabel
    adView.callToActionView = ctaButton
    adView.adChoicesView = adChoicesView

    headlineLabel.text = nativeAd.headline
    bodyLabel.text = nativeAd.body
    advertiserLabel.text = nativeAd.advertiser
    ctaButton.setTitle(nativeAd.callToAction, for: .normal)

    bodyLabel.isHidden = nativeAd.body == nil
    advertiserLabel.isHidden = nativeAd.advertiser == nil
    ctaButton.isHidden = nativeAd.callToAction == nil

    if let iconImage = nativeAd.icon?.image {
      iconView.image = iconImage
      iconView.isHidden = false
    } else {
      iconView.isHidden = true
    }

    mediaView.mediaContent = nativeAd.mediaContent
    adView.nativeAd = nativeAd
    return adView
  }
}