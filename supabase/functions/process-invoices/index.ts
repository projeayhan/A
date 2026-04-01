import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { PDFDocument, rgb, StandardFonts } from "npm:pdf-lib@1.17.1";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function logToDb(level: string, message: string, source: string, errorDetail?: string, metadata?: Record<string, unknown>) {
  try {
    await supabase.from('app_logs').insert({
      app_name: 'edge_function_invoices',
      level,
      message: message.substring(0, 2000),
      source,
      error_detail: errorDetail?.substring(0, 5000),
      metadata,
    });
  } catch (_) { /* silent */ }
}

// Turkish month names
const TR_MONTHS = [
  "Ocak", "Subat", "Mart", "Nisan", "Mayis", "Haziran",
  "Temmuz", "Agustos", "Eylul", "Ekim", "Kasim", "Aralik",
];

function formatCurrency(amount: number): string {
  return `${amount.toFixed(2)} TL`;
}

function formatDate(date: Date): string {
  const d = date.getDate().toString().padStart(2, "0");
  const m = (date.getMonth() + 1).toString().padStart(2, "0");
  const y = date.getFullYear();
  return `${d}.${m}.${y}`;
}

async function generateInvoicePdf(
  invoice: Record<string, unknown>,
  items: Record<string, unknown>[]
): Promise<Uint8Array> {
  const pdfDoc = await PDFDocument.create();
  const font = await pdfDoc.embedFont(StandardFonts.Helvetica);
  const fontBold = await pdfDoc.embedFont(StandardFonts.HelveticaBold);
  const page = pdfDoc.addPage([595, 842]); // A4
  const { height } = page.getSize();
  let y = height - 50;

  const drawText = (
    text: string,
    x: number,
    yPos: number,
    size = 10,
    bold = false,
    color = rgb(0, 0, 0)
  ) => {
    page.drawText(text || "", {
      x,
      y: yPos,
      size,
      font: bold ? fontBold : font,
      color,
    });
  };

  // Header - Company name
  drawText(String(invoice.seller_name ?? "SuperCyp Teknoloji A.S."), 50, y, 18, true);
  y -= 20;
  drawText(String(invoice.seller_address ?? ""), 50, y, 9);
  y -= 14;
  drawText("Tel: +90 212 555 00 00", 50, y, 9);
  y -= 14;
  drawText("E-posta: fatura@supercyp.com", 50, y, 9);

  // Invoice box (right side)
  const boxY = height - 50;
  page.drawRectangle({
    x: 400,
    y: boxY - 55,
    width: 160,
    height: 60,
    borderColor: rgb(0.7, 0.7, 0.7),
    borderWidth: 1,
  });
  drawText("FATURA", 440, boxY - 15, 14, true, rgb(0, 0.2, 0.6));
  drawText(`No: ${invoice.invoice_number}`, 415, boxY - 32, 10);
  drawText(
    `Tarih: ${formatDate(new Date(String(invoice.created_at)))}`,
    415,
    boxY - 46,
    10
  );

  y -= 30;

  // Seller / Buyer info boxes
  const infoY = y;

  // Seller box
  page.drawRectangle({
    x: 50,
    y: infoY - 65,
    width: 230,
    height: 70,
    color: rgb(0.95, 0.95, 0.95),
  });
  drawText("Satici Bilgileri", 60, infoY - 15, 11, true);
  drawText(String(invoice.seller_name ?? ""), 60, infoY - 30, 9);
  drawText(
    `Vergi Dairesi: ${invoice.seller_tax_office ?? ""}`,
    60,
    infoY - 43,
    9
  );
  drawText(`Vergi No: ${invoice.seller_tax_number ?? ""}`, 60, infoY - 56, 9);

  // Buyer box
  page.drawRectangle({
    x: 310,
    y: infoY - 65,
    width: 250,
    height: 70,
    color: rgb(0.95, 0.95, 0.95),
  });
  drawText("Alici Bilgileri", 320, infoY - 15, 11, true);
  drawText(String(invoice.buyer_name ?? ""), 320, infoY - 30, 9);
  if (invoice.buyer_tax_number) {
    drawText(
      `Vergi/TC No: ${invoice.buyer_tax_number}`,
      320,
      infoY - 43,
      9
    );
  }
  if (invoice.buyer_email) {
    drawText(`E-posta: ${invoice.buyer_email}`, 320, infoY - 43 - (invoice.buyer_tax_number ? 13 : 0), 9);
  }

  y = infoY - 90;

  // Table header
  page.drawRectangle({
    x: 50,
    y: y - 20,
    width: 510,
    height: 25,
    color: rgb(0, 0.2, 0.6),
  });
  drawText("Aciklama", 60, y - 14, 10, true, rgb(1, 1, 1));
  drawText("Miktar", 330, y - 14, 10, true, rgb(1, 1, 1));
  drawText("Birim Fiyat", 400, y - 14, 10, true, rgb(1, 1, 1));
  drawText("Toplam", 500, y - 14, 10, true, rgb(1, 1, 1));

  y -= 25;

  // Table rows
  if (items.length > 0) {
    for (const item of items) {
      page.drawLine({
        start: { x: 50, y: y },
        end: { x: 560, y: y },
        color: rgb(0.85, 0.85, 0.85),
      });
      y -= 18;
      drawText(String(item.description ?? "-"), 60, y, 9);
      drawText(String(item.quantity ?? "1"), 340, y, 9);
      drawText(formatCurrency(Number(item.unit_price ?? 0)), 400, y, 9);
      drawText(formatCurrency(Number(item.total ?? 0)), 500, y, 9);
    }
  } else {
    y -= 18;
    drawText("Komisyon Hizmeti", 60, y, 9);
    drawText("1", 340, y, 9);
    drawText(formatCurrency(Number(invoice.subtotal ?? 0)), 400, y, 9);
    drawText(formatCurrency(Number(invoice.subtotal ?? 0)), 500, y, 9);
  }

  // Bottom line
  y -= 10;
  page.drawLine({
    start: { x: 50, y: y },
    end: { x: 560, y: y },
    color: rgb(0.7, 0.7, 0.7),
  });

  // Totals
  y -= 30;
  drawText("Ara Toplam:", 400, y, 10);
  drawText(formatCurrency(Number(invoice.subtotal ?? 0)), 500, y, 10);
  y -= 18;
  const kdvPercent = Math.round(Number(invoice.kdv_rate ?? 0.2) * 100);
  drawText(`KDV (%${kdvPercent}):`, 400, y, 10);
  drawText(formatCurrency(Number(invoice.kdv_amount ?? 0)), 500, y, 10);
  y -= 5;
  page.drawLine({
    start: { x: 400, y: y },
    end: { x: 560, y: y },
    color: rgb(0.5, 0.5, 0.5),
  });
  y -= 18;
  drawText("Genel Toplam:", 400, y, 12, true);
  drawText(formatCurrency(Number(invoice.total ?? 0)), 495, y, 12, true);

  // Ödeme yöntemi kutusu
  const pm = String(invoice.payment_method ?? "");
  if (pm) {
    y -= 30;
    const pmLabel = pm === "online" ? "Online (Stripe)"
      : pm === "cash" ? "Nakit"
      : pm === "card" ? "Kredi Karti"
      : pm === "credit_card_on_delivery" ? "Kapida Kart"
      : pm;
    const isOnline = pm === "online";
    const boxColor = isOnline ? rgb(0.9, 1, 0.9) : rgb(0.95, 0.95, 0.95);
    const borderColor = isOnline ? rgb(0.4, 0.8, 0.4) : rgb(0.7, 0.7, 0.7);
    const textColor = isOnline ? rgb(0, 0.5, 0) : rgb(0.3, 0.3, 0.3);

    page.drawRectangle({
      x: 380,
      y: y - 20,
      width: 180,
      height: 25,
      color: boxColor,
      borderColor: borderColor,
      borderWidth: 1,
    });
    drawText("Odeme:", 390, y - 14, 10, true);
    drawText(pmLabel, 470, y - 14, 10, true, textColor);
  }

  return await pdfDoc.save();
}

async function sendInvoiceEmail(
  email: string,
  invoiceNumber: string,
  buyerName: string,
  period: string,
  pdfUrl: string
): Promise<boolean> {
  if (!RESEND_API_KEY) {
    console.log("RESEND_API_KEY not set, skipping email for", email);
    return false;
  }

  try {
    const periodParts = period.split("-");
    const monthName =
      TR_MONTHS[parseInt(periodParts[1]) - 1] ?? period;
    const periodLabel = `${monthName} ${periodParts[0]}`;

    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "SuperCyp Fatura <fatura@supercyp.com>",
        to: [email],
        subject: `${periodLabel} Donemi Fatura - ${invoiceNumber}`,
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #1a365d;">SuperCyp Fatura Bildirimi</h2>
            <p>Sayin ${buyerName},</p>
            <p><strong>${periodLabel}</strong> donemine ait faturaniz olusturulmustur.</p>
            <p><strong>Fatura No:</strong> ${invoiceNumber}</p>
            <p>Faturanizi asagidaki linkten indirebilirsiniz:</p>
            <a href="${pdfUrl}"
               style="display: inline-block; padding: 12px 24px; background: #2563eb; color: white; text-decoration: none; border-radius: 8px; margin: 16px 0;">
              Faturayi Indir (PDF)
            </a>
            <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 24px 0;">
            <p style="color: #6b7280; font-size: 12px;">Bu e-posta SuperCyp sistemi tarafindan otomatik olarak gonderilmistir.</p>
          </div>
        `,
      }),
    });

    if (!response.ok) {
      const err = await response.text();
      console.error("Resend API error:", err);
      return false;
    }
    return true;
  } catch (e) {
    console.error("Email send error:", e);
    return false;
  }
}

Deno.serve(async (req: Request) => {
  try {
    const { action, period, invoice_ids } = await req.json();

    // Find invoices without PDF
    let query = supabase
      .from("invoices")
      .select("*")
      .is("pdf_url", null)
      .eq("status", "issued")
      .eq("source_type", "merchant_commission");

    if (invoice_ids && invoice_ids.length > 0) {
      query = query.in("id", invoice_ids);
    } else if (period) {
      query = query.eq("invoice_period", period);
    }

    const { data: invoices, error: fetchErr } = await query.limit(100);
    if (fetchErr) throw fetchErr;
    if (!invoices || invoices.length === 0) {
      return new Response(
        JSON.stringify({ message: "No pending invoices", processed: 0 }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    let processed = 0;
    let emailed = 0;
    const errors: { id: string; error: string }[] = [];

    for (const invoice of invoices) {
      try {
        // Fetch items
        const { data: items } = await supabase
          .from("invoice_items")
          .select("*")
          .eq("invoice_id", invoice.id)
          .order("sort_order");

        // Generate PDF
        const pdfBytes = await generateInvoicePdf(invoice, items ?? []);

        // Upload to storage
        const fileName = `invoices/${invoice.id}.pdf`;
        const { error: uploadErr } = await supabase.storage
          .from("invoices")
          .upload(fileName, pdfBytes, {
            contentType: "application/pdf",
            upsert: true,
          });

        if (uploadErr) {
          console.error("Upload error:", uploadErr);
          errors.push({ id: invoice.id, error: `Upload: ${uploadErr.message}` });
          continue;
        }

        const {
          data: { publicUrl },
        } = supabase.storage.from("invoices").getPublicUrl(fileName);

        // Update invoice with PDF URL
        await supabase
          .from("invoices")
          .update({ pdf_url: publicUrl })
          .eq("id", invoice.id);

        processed++;

        // Send email if buyer has email
        if (invoice.buyer_email) {
          const sent = await sendInvoiceEmail(
            invoice.buyer_email,
            invoice.invoice_number,
            invoice.buyer_name,
            invoice.invoice_period ?? "",
            publicUrl
          );
          if (sent) {
            emailed++;
            await supabase
              .from("invoices")
              .update({ sent_at: new Date().toISOString() })
              .eq("id", invoice.id);
          }
        }
      } catch (e) {
        console.error(`Error processing invoice ${invoice.id}:`, e);
        await logToDb('error', `Invoice processing failed: ${invoice.id}`, 'process-invoices:generate', e instanceof Error ? e.message : String(e), { invoice_id: invoice.id });
        errors.push({
          id: invoice.id,
          error: e instanceof Error ? e.message : String(e),
        });
      }
    }

    await logToDb('info', `Invoices processed: ${processed}/${invoices.length}, emailed: ${emailed}`, 'process-invoices:batch', undefined, { total: invoices.length, processed, emailed, error_count: errors.length });

    return new Response(
      JSON.stringify({
        message: "Invoices processed",
        total: invoices.length,
        processed,
        emailed,
        errors,
      }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (e) {
    console.error("Process invoices error:", e);
    await logToDb('error', 'Process invoices failed', 'process-invoices:handler', e instanceof Error ? e.message : String(e));
    return new Response(
      JSON.stringify({
        error: e instanceof Error ? e.message : String(e),
      }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
