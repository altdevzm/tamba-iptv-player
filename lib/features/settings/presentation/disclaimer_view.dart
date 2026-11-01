import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class DisclaimerView extends StatelessWidget {
  const DisclaimerView({super.key});

  static const _sections = <_DisclaimerSection>[
    _DisclaimerSection(
      '1. About Tamba IPTV',
      paragraphs: [
        'Tamba IPTV is an open-source IPTV media player application developed to provide users with tools to organize, manage, and play media from external sources.',
        'Tamba IPTV is software only. It does not provide, host, operate, sell, distribute, or maintain IPTV playlists, television channels, movies, television shows, music, or any other digital media content.',
        'The application does not include or supply paid IPTV subscriptions or third-party streaming services.',
      ],
    ),
    _DisclaimerSection(
      '2. No Content Provision',
      paragraphs: [
        'Tamba IPTV does not own, operate, control, or maintain the external content sources that users may connect to through the application.',
        'Users are responsible for independently obtaining their own playlists, streaming URLs, media files, and other content from sources they are legally authorized to access.',
        'Tamba IPTV does not guarantee the legality, accuracy, availability, quality, or reliability of any external content source.',
      ],
    ),
    _DisclaimerSection(
      '3. Open-Source Nature',
      paragraphs: [
        'Tamba IPTV is made available as open-source software, allowing users and developers to inspect, use, modify, and redistribute the source code in accordance with the applicable open-source licence.',
        'The rights and obligations associated with copying, modifying, and redistributing the software are governed by the licence accompanying the source code.',
        'The availability of the source code does not grant users ownership or distribution rights over third-party media content accessed through the application.',
        'Any modifications, forks, unofficial builds, or third-party distributions are the responsibility of their respective maintainers.',
      ],
    ),
    _DisclaimerSection(
      '4. User Responsibility',
      paragraphs: [
        'Users are solely responsible for their use of Tamba IPTV and any external content sources they configure.',
        'Users must:',
      ],
      bullets: [
        'Obtain playlists and streaming links from legitimate sources.',
        'Ensure they have the necessary rights or authorization to access media content.',
        'Comply with applicable copyright and intellectual property laws.',
        'Avoid using the application to access or distribute unauthorized content.',
        'Take responsibility for subscriptions and agreements made with independent IPTV providers.',
      ],
    ),
    _DisclaimerSection(
      '5. Third-Party Content and Services',
      paragraphs: [
        'Tamba IPTV may support connections to third-party IPTV providers, streaming servers, APIs, playlists, and other external services.',
        'These services are independent of Tamba IPTV.',
        'Tamba IPTV is not responsible for their content, operations, pricing, availability, security, or business practices.',
        'Any transactions, subscriptions, or agreements between users and third-party providers are exclusively between those parties.',
      ],
    ),
    _DisclaimerSection(
      '6. Copyright and Intellectual Property',
      paragraphs: [
        'Tamba IPTV respects the rights of copyright owners, broadcasters, developers, and content creators.',
        'The application is designed as a general-purpose media playback tool and is not intended to promote copyright infringement or unauthorized content distribution.',
        'All third-party trademarks, logos, channel names, media titles, and copyrighted materials remain the property of their respective owners.',
        'Their display through user-configured sources does not imply ownership, endorsement, or affiliation with Tamba IPTV.',
      ],
    ),
    _DisclaimerSection(
      '7. No Affiliation',
      paragraphs: [
        'Tamba IPTV is an independent open-source software project.',
        'Unless expressly stated otherwise, it is not affiliated with, sponsored by, endorsed by, or officially associated with any television broadcaster, streaming platform, IPTV provider, media company, or content distributor.',
      ],
    ),
    _DisclaimerSection(
      '8. No Warranty',
      paragraphs: [
        'To the extent permitted by the applicable open-source licence and applicable law, Tamba IPTV is provided on an "AS IS" and "AS AVAILABLE" basis, without warranties of any kind.',
        'We do not guarantee that the software will operate without errors, interruptions, compatibility issues, or security vulnerabilities.',
        'Users are responsible for evaluating the software and its suitability for their intended use.',
      ],
    ),
    _DisclaimerSection(
      '9. Limitation of Liability',
      paragraphs: [
        'To the maximum extent permitted by applicable law, the developers and maintainers of Tamba IPTV shall not be liable for damages, claims, losses, or legal consequences resulting from:',
      ],
      bullets: [
        "The user's configuration or use of the application.",
        'Third-party playlists or streaming sources.',
        'Unauthorized access to or distribution of copyrighted content by users.',
        'External provider subscriptions or transactions.',
        'Third-party server failures or service interruptions.',
        'Unofficial modifications or redistributed versions of the software.',
      ],
      footer: 'Nothing in this section excludes liability that cannot legally be excluded.',
    ),
    _DisclaimerSection(
      '10. Software Licensing and Contributions',
      paragraphs: [
        'Use, modification, and redistribution of Tamba IPTV are subject to the terms of its designated open-source licence.',
        'Contributors and third-party developers are responsible for ensuring that their contributions comply with the project\'s licensing requirements and applicable laws.',
        'The project name, branding, logos, and other trademarks may be subject to separate usage restrictions, even where the source code is open source.',
      ],
    ),
    _DisclaimerSection(
      '11. Updates to This Disclaimer',
      paragraphs: [
        'This disclaimer may be updated periodically to reflect changes in the project, software functionality, or applicable legal requirements.',
        'Users should review the latest version published through the official Tamba IPTV website or project repository.',
      ],
    ),
    _DisclaimerSection(
      '12. Final Acknowledgement',
      paragraphs: ['By using Tamba IPTV, you acknowledge that:'],
      bullets: [
        'Tamba IPTV is an open-source media player, not a content provider.',
        'No IPTV playlists or digital media content are supplied by the project.',
        'You are responsible for providing and legally accessing your own content sources.',
        'External providers operate independently of Tamba IPTV.',
        "Your use of the application must comply with applicable laws and the software's open-source licence.",
      ],
      footer:
          'TAMBA IPTV\nYour Media. Your Sources. Your Control.\n\nAn independent open-source IPTV media player. No playlists. No bundled content. Just software.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 32,
          vertical: isMobile ? 16 : 28,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Open-Source Software Disclaimer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'TAMBA IPTV  •  Effective Date: 1 November 2026',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _sections
                        .map((section) => _buildSection(section))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(_DisclaimerSection section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...section.paragraphs.map(
            (paragraph) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                paragraph,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  height: 1.5,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          ...section.bullets.map(
            (bullet) => Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•  ',
                    style: TextStyle(
                      color: AppColors.primary.withValues(alpha: 0.9),
                      height: 1.5,
                      fontSize: 13,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      bullet,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        height: 1.5,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (section.footer != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                section.footer!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DisclaimerSection {
  final String title;
  final List<String> paragraphs;
  final List<String> bullets;
  final String? footer;

  const _DisclaimerSection(
    this.title, {
    this.paragraphs = const [],
    this.bullets = const [],
    this.footer,
  });
}
