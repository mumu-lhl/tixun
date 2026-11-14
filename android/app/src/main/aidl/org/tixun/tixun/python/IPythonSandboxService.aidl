package org.tixun.tixun.python;
import android.os.ParcelFileDescriptor;
oneway interface IPythonSandboxService {
    void run(in ParcelFileDescriptor input, in ParcelFileDescriptor output);
    void stop();
}
