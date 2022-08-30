# Internet images

In principle, we should be able to supply an internet image URL direct to the toast notifier: in practice, this [doesn't seem to work outside Universal Windows Platform apps](https://stackoverflow.com/questions/50394484/web-based-images-not-working-in-toast-created-by-nodert-win10-windows-ui-notifi).  So when `EnableWebImages` is set in the configuration, LightlyToasted will download web images into a temporary folder, then use the path of the local download in the notification.

The default maximum size is 256KB: files larger than this will not be downloaded.  This can be adjusted using the `MaxWebImageSizeKb` configuration parameter.

When the same image URL is used in multiple notifications:

* The first successful local download will be reused, rather than repeatedly downloading the image.
* Failed downloads will not be instantly reattempted, but will be retried if another notification requires the same image, up to a maximum 3 attempts per URL.