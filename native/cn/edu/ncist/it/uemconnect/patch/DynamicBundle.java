package cn.edu.ncist.it.uemconnect.patch;

import android.content.Context;
import android.content.res.Resources;
import android.os.Build;
import android.util.Log;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Locale;

/** Only the pinned upstream Hermes string constants are changed. */
public final class DynamicBundle {
    private DynamicBundle() {}
    // Generated from the audited upstream string table by scripts/patch.py.
    private static final int[] OFFSETS = { /* OFFSETS */ };
    private static final String[] ORIGINAL = { /* ORIGINAL */ };
    private static final String[] RESOURCES = { /* RESOURCES */ };
    private static final String BUNDLE_SHA256 = "/* BUNDLE_SHA256 */";

    public static synchronized String prepare(Context context, String assetUrl) {
        if (Build.VERSION.SDK_INT < 31 || !"assets://index.android.bundle".equals(assetUrl)) return null;
        try {
            byte[] data;
            try (InputStream in = context.getAssets().open("index.android.bundle");
                 ByteArrayOutputStream out = new ByteArrayOutputStream()) {
                byte[] buffer = new byte[16384];
                int n;
                while ((n = in.read(buffer)) != -1) out.write(buffer, 0, n);
                data = out.toByteArray();
            }
            if (!hex(MessageDigest.getInstance("SHA-256").digest(data)).equals(BUNDLE_SHA256)) {
                throw new IOException("Upstream bundle hash mismatch");
            }
            // Preserve the header, instructions, function table and string lengths.
            Resources resources = context.getResources();
            for (int i = 0; i < OFFSETS.length; i++) {
                byte[] expected = ORIGINAL[i].getBytes(StandardCharsets.US_ASCII);
                for (int j = 0; j < 7; j++) {
                    if (data[OFFSETS[i] + j] != expected[j]) throw new IOException("Palette offset mismatch");
                }
                int id = resources.getIdentifier(RESOURCES[i], "color", "android");
                if (id == 0) throw new IOException("System palette missing: " + RESOURCES[i]);
                int color = resources.getColor(id, context.getTheme());
                // Keep dark surfaces subtly distinct using neutral tonal steps.
                if (ORIGINAL[i].equals("#101418")) {
                    color = blend(color, resources.getColor(resources.getIdentifier("system_neutral1_900", "color", "android"), context.getTheme()), .60f);
                } else if (ORIGINAL[i].equals("#20252B")) {
                    color = blend(resources.getColor(resources.getIdentifier("system_neutral1_900", "color", "android"), context.getTheme()), color, .40f);
                }
                byte[] replacement = String.format(Locale.ROOT, "#%06X", color & 0xFFFFFF).getBytes(StandardCharsets.US_ASCII);
                System.arraycopy(replacement, 0, data, OFFSETS[i], 7);
                if (ORIGINAL[i].equals("#145FA8")) Log.i("UEMDynamicColor", "primary_light=" + new String(replacement, StandardCharsets.US_ASCII));
            }
            MessageDigest checksum = MessageDigest.getInstance("SHA-1");
            checksum.update(data, 0, data.length - 20);
            System.arraycopy(checksum.digest(), 0, data, data.length - 20, 20);
            File directory = new File(context.getFilesDir(), "dynamic-theme");
            if (!directory.isDirectory() && !directory.mkdirs()) throw new IOException("Cannot create theme directory");
            File output = new File(directory, "index.android.bundle");
            File temp = new File(directory, "index.android.bundle.tmp");
            if (temp.exists() && !temp.delete()) throw new IOException("Cannot replace staging bundle");
            // Android 14 dynamic code loading requires read-only files before writing.
            try (FileOutputStream out = new FileOutputStream(temp)) {
                if (!temp.setReadOnly()) throw new IOException("Cannot mark theme bundle read-only");
                out.write(data);
                out.getFD().sync();
            }
            if (output.exists() && !output.delete()) throw new IOException("Cannot replace theme bundle");
            if (!temp.renameTo(output)) throw new IOException("Cannot commit theme bundle");
            Log.i("UEMDynamicColor", "System palette applied to " + OFFSETS.length + " theme constants");
            return output.getAbsolutePath();
        } catch (Exception error) {
            Log.e("UEMDynamicColor", "Keeping upstream theme", error);
            return null;
        }
    }

    private static int blend(int a, int b, float weight) {
        int r = Math.round(((a >> 16) & 255) * (1 - weight) + ((b >> 16) & 255) * weight);
        int g = Math.round(((a >> 8) & 255) * (1 - weight) + ((b >> 8) & 255) * weight);
        int blue = Math.round((a & 255) * (1 - weight) + (b & 255) * weight);
        return 0xFF000000 | r << 16 | g << 8 | blue;
    }

    private static String hex(byte[] bytes) {
        StringBuilder result = new StringBuilder();
        for (byte b : bytes) result.append(String.format(Locale.ROOT, "%02x", b & 255));
        return result.toString();
    }
}
