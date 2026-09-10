import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import '../../../../core/themes/aether_colors.dart';

class AetherAttachmentCard extends StatelessWidget {
  final String path;
  
  const AetherAttachmentCard({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    final fileName = path.split('/').last;
    final extension = fileName.split('.').last.toLowerCase();

    // Type Detection Engine
    final isImage = ['jpg', 'jpeg', 'png', 'webp'].contains(extension);
    final isPdf = extension == 'pdf';
    final isAudio = ['m4a', 'mp3', 'wav'].contains(extension);
    final isVideo = ['mp4', 'mov'].contains(extension);

    // Premium Colors based on file type
    final Color accentColor = isImage ? const Color(0xFF38BDF8) : // Sky Blue
                              isPdf ? const Color(0xFFFB7185) : // Rose Red
                              isAudio ? const Color(0xFF34F5C5) : // Mint Green
                              isVideo ? const Color(0xFFA78BFA) : // Violet
                              Colors.white54;

    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        // SAFE NATIVE HANDOFF: Prevents Flutter from crashing on heavy/unknown files
        final result = await OpenFilex.open(path);
        if (result.type != ResultType.done && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open file: ${result.message}', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent)
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.035),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: [
                  // Premium Thumbnail Box
                  Container(
                    width: 70,
                    height: 70,
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.black26,
                      gradient: isImage ? null : RadialGradient(
                        colors: [accentColor.withValues(alpha: 0.2), Colors.transparent]
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: isImage 
                      ? Image.file(file, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.broken_image_rounded, color: Colors.white38))
                      : Center(
                          child: Icon(
                            isPdf ? Icons.picture_as_pdf_rounded :
                            isAudio ? Icons.audiotrack_rounded :
                            isVideo ? Icons.video_library_rounded : Icons.insert_drive_file_rounded,
                            color: accentColor,
                            size: 28,
                          ),
                        ),
                  ),
                  
                  // Metadata Section
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(6)
                            ),
                            child: Text(
                              isImage ? "Image Document" :
                              isPdf ? "PDF Document" :
                              isAudio ? "Voice Note" : "Attached File",
                              style: TextStyle(color: accentColor.withValues(alpha: 0.9), fontSize: 10.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Action Button
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle
                      ),
                      child: const Icon(Icons.open_in_new_rounded, color: Colors.white54, size: 16),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}